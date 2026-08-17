using System.Reflection.Metadata;
using System.Reflection.PortableExecutable;
using System.Collections.Immutable;
using System.Reflection.Emit;
using System.Reflection.Metadata.Ecma335;

if (args.Length is < 1 or > 2)
{
    Console.Error.WriteLine("Usage: MetadataInspector <assembly-path> [type-or-method-filter]");
    return 2;
}

var methodFilter = args.Length == 2 ? args[1] : "";
var dumpIl = methodFilter.StartsWith("il:", StringComparison.OrdinalIgnoreCase);
if (dumpIl)
{
    methodFilter = methodFilter[3..];
}

using var stream = File.OpenRead(args[0]);
using var peReader = new PEReader(stream);
var reader = peReader.GetMetadataReader();

foreach (var typeHandle in reader.TypeDefinitions)
{
    var type = reader.GetTypeDefinition(typeHandle);
    var typeName = reader.GetString(type.Name);
    var typeNamespace = reader.GetString(type.Namespace);

    var fullyQualifiedTypeName = typeNamespace + "." + typeName;
    var typeMatches = string.IsNullOrWhiteSpace(methodFilter) ||
        fullyQualifiedTypeName.Contains(methodFilter, StringComparison.OrdinalIgnoreCase);
    var matchingMethods = type.GetMethods()
        .Select(handle => (Handle: handle, Definition: reader.GetMethodDefinition(handle)))
        .Where(item => string.IsNullOrWhiteSpace(methodFilter) ||
            reader.GetString(item.Definition.Name).Contains(methodFilter, StringComparison.OrdinalIgnoreCase))
        .ToArray();

    if (!typeMatches && matchingMethods.Length == 0)
    {
        continue;
    }

    Console.WriteLine($"TYPE {fullyQualifiedTypeName}");
    foreach (var item in matchingMethods)
    {
        var method = item.Definition;
        var methodName = reader.GetString(method.Name);

        var parameters = method.GetParameters()
            .Select(handle => reader.GetParameter(handle))
            .Where(parameter => parameter.SequenceNumber > 0)
            .OrderBy(parameter => parameter.SequenceNumber)
            .Select(parameter => $"{parameter.SequenceNumber}:{reader.GetString(parameter.Name)}")
            .ToArray();
        var signature = method.DecodeSignature(new TypeNameProvider(), genericContext: null);

        Console.WriteLine($"METHOD {methodName} ({string.Join(", ", parameters)}) => {signature.ReturnType} ({string.Join(", ", signature.ParameterTypes)})");
        if (dumpIl && methodName.Contains(methodFilter, StringComparison.OrdinalIgnoreCase))
        {
            Console.WriteLine(Disassemble(ImmutableArray.CreateRange(peReader.GetMethodBody(method.RelativeVirtualAddress).GetILBytes()), reader));
        }
    }

    if (typeMatches)
    {
        foreach (var fieldHandle in type.GetFields())
        {
            var field = reader.GetFieldDefinition(fieldHandle);
            var signature = field.DecodeSignature(new TypeNameProvider(), genericContext: null);
            Console.WriteLine($"FIELD {reader.GetString(field.Name)} => {signature}");
        }

        foreach (var propertyHandle in type.GetProperties())
        {
            var property = reader.GetPropertyDefinition(propertyHandle);
            var signature = property.DecodeSignature(new TypeNameProvider(), genericContext: null);
            Console.WriteLine($"PROPERTY {reader.GetString(property.Name)} => {signature.ReturnType} ({string.Join(", ", signature.ParameterTypes)})");
        }
    }
}

foreach (var referenceHandle in reader.TypeReferences)
{
    var reference = reader.GetTypeReference(referenceHandle);
    var fullName = reader.GetString(reference.Namespace) + "." + reader.GetString(reference.Name);
    if (!string.IsNullOrWhiteSpace(methodFilter) && fullName.Contains(methodFilter, StringComparison.OrdinalIgnoreCase))
    {
        Console.WriteLine($"TYPE-REFERENCE {fullName}");
    }
}

return 0;

static string Disassemble(ImmutableArray<byte> bytes, MetadataReader reader)
{
    var oneByte = new OpCode[0x100];
    var twoByte = new OpCode[0x100];
    foreach (var field in typeof(OpCodes).GetFields(System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Static))
    {
        if (field.GetValue(null) is not OpCode opcode) continue;
        var value = unchecked((ushort)opcode.Value);
        if (value <= 0xff) oneByte[value] = opcode;
        else if ((value & 0xff00) == 0xfe00) twoByte[value & 0xff] = opcode;
    }
    var output = new System.Text.StringBuilder();
    var offset = 0;
    while (offset < bytes.Length)
    {
        var instructionOffset = offset;
        var opcode = bytes[offset++] == 0xfe ? twoByte[bytes[offset++]] : oneByte[bytes[instructionOffset]];
        output.Append($"  IL_{instructionOffset:x4}: {opcode.Name}");
        var operandOffset = offset;
        string? operand = null;
        switch (opcode.OperandType)
        {
            case OperandType.InlineNone: break;
            case OperandType.ShortInlineI: operand = ((sbyte)bytes[offset]).ToString(); offset += 1; break;
            case OperandType.InlineI: operand = BitConverter.ToInt32(bytes.AsSpan(offset, 4)).ToString(); offset += 4; break;
            case OperandType.InlineI8: operand = BitConverter.ToInt64(bytes.AsSpan(offset, 8)).ToString(); offset += 8; break;
            case OperandType.ShortInlineR: operand = BitConverter.ToSingle(bytes.AsSpan(offset, 4)).ToString(); offset += 4; break;
            case OperandType.InlineR: operand = BitConverter.ToDouble(bytes.AsSpan(offset, 8)).ToString(); offset += 8; break;
            case OperandType.ShortInlineBrTarget: operand = $"IL_{offset + 1 + (sbyte)bytes[offset]:x4}"; offset += 1; break;
            case OperandType.InlineBrTarget: operand = $"IL_{offset + 4 + BitConverter.ToInt32(bytes.AsSpan(offset, 4)):x4}"; offset += 4; break;
            case OperandType.ShortInlineVar: operand = bytes[offset].ToString(); offset += 1; break;
            case OperandType.InlineVar: operand = BitConverter.ToUInt16(bytes.AsSpan(offset, 2)).ToString(); offset += 2; break;
            case OperandType.InlineString:
                operand = '"' + reader.GetUserString(MetadataTokens.UserStringHandle(BitConverter.ToInt32(bytes.AsSpan(offset, 4)) & 0x00ffffff)) + '"'; offset += 4; break;
            case OperandType.InlineField:
            case OperandType.InlineMethod:
            case OperandType.InlineType:
            case OperandType.InlineTok:
            case OperandType.InlineSig:
                var token = BitConverter.ToInt32(bytes.AsSpan(offset, 4));
                operand = ResolveToken(reader, token); offset += 4; break;
            case OperandType.InlineSwitch:
                var count = BitConverter.ToInt32(bytes.AsSpan(offset, 4)); offset += 4;
                var baseOffset = offset + count * 4;
                operand = string.Join(", ", Enumerable.Range(0, count).Select(i => $"IL_{baseOffset + BitConverter.ToInt32(bytes.AsSpan(offset + i * 4, 4)):x4}"));
                offset += count * 4; break;
        }
        if (operand != null) output.Append(' ').Append(operand);
        output.AppendLine();
    }
    return output.ToString();
}

static string ResolveToken(MetadataReader reader, int token)
{
    try
    {
        var handle = MetadataTokens.EntityHandle(token);
        return handle.Kind switch
        {
            HandleKind.MethodDefinition => "METHOD " + reader.GetString(reader.GetMethodDefinition((MethodDefinitionHandle)handle).Name),
            HandleKind.MemberReference => "MEMBER " + reader.GetString(reader.GetMemberReference((MemberReferenceHandle)handle).Name),
            HandleKind.FieldDefinition => "FIELD " + reader.GetString(reader.GetFieldDefinition((FieldDefinitionHandle)handle).Name),
            HandleKind.TypeDefinition => "TYPE " + reader.GetString(reader.GetTypeDefinition((TypeDefinitionHandle)handle).Name),
            HandleKind.TypeReference => "TYPE " + reader.GetString(reader.GetTypeReference((TypeReferenceHandle)handle).Name),
            _ => handle.Kind + " 0x" + token.ToString("x8")
        };
    }
    catch { return "0x" + token.ToString("x8"); }
}

sealed class TypeNameProvider : ISignatureTypeProvider<string, object?>
{
    public string GetArrayType(string elementType, ArrayShape shape) => elementType + "[]";
    public string GetByReferenceType(string elementType) => "ref " + elementType;
    public string GetFunctionPointerType(MethodSignature<string> signature) => "fnptr";
    public string GetGenericInstantiation(string genericType, ImmutableArray<string> typeArguments) => genericType + "<" + string.Join(", ", typeArguments) + ">";
    public string GetGenericMethodParameter(object? genericContext, int index) => "!!" + index;
    public string GetGenericTypeParameter(object? genericContext, int index) => "!" + index;
    public string GetModifiedType(string modifier, string unmodifiedType, bool isRequired) => unmodifiedType;
    public string GetPinnedType(string elementType) => elementType;
    public string GetPointerType(string elementType) => elementType + "*";
    public string GetPrimitiveType(PrimitiveTypeCode typeCode) => typeCode.ToString();
    public string GetSZArrayType(string elementType) => elementType + "[]";
    public string GetTypeFromDefinition(MetadataReader reader, TypeDefinitionHandle handle, byte rawTypeKind)
    {
        var type = reader.GetTypeDefinition(handle);
        return reader.GetString(type.Namespace) + "." + reader.GetString(type.Name);
    }
    public string GetTypeFromReference(MetadataReader reader, TypeReferenceHandle handle, byte rawTypeKind)
    {
        var type = reader.GetTypeReference(handle);
        return reader.GetString(type.Namespace) + "." + reader.GetString(type.Name);
    }
    public string GetTypeFromSpecification(MetadataReader reader, object? genericContext, TypeSpecificationHandle handle, byte rawTypeKind) => reader.GetTypeSpecification(handle).DecodeSignature(this, genericContext);
}
