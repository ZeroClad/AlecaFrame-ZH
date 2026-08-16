using System.Reflection.Metadata;
using System.Reflection.PortableExecutable;
using System.Collections.Immutable;

if (args.Length is < 1 or > 2)
{
    Console.Error.WriteLine("Usage: MetadataInspector <assembly-path> [method-name-filter]");
    return 2;
}

var methodFilter = args.Length == 2 ? args[1] : "";

using var stream = File.OpenRead(args[0]);
using var peReader = new PEReader(stream);
var reader = peReader.GetMetadataReader();

foreach (var typeHandle in reader.TypeDefinitions)
{
    var type = reader.GetTypeDefinition(typeHandle);
    var typeName = reader.GetString(type.Name);
    var typeNamespace = reader.GetString(type.Namespace);

    if (!typeName.Contains("OverwolfWrapper", StringComparison.OrdinalIgnoreCase) &&
        !typeName.Contains("Plugin", StringComparison.OrdinalIgnoreCase))
    {
        continue;
    }

    Console.WriteLine($"TYPE {typeNamespace}.{typeName}");
    foreach (var methodHandle in type.GetMethods())
    {
        var method = reader.GetMethodDefinition(methodHandle);
        var methodName = reader.GetString(method.Name);
        if (!string.IsNullOrWhiteSpace(methodFilter) &&
            !methodName.Contains(methodFilter, StringComparison.OrdinalIgnoreCase))
        {
            continue;
        }

        var parameters = method.GetParameters()
            .Select(handle => reader.GetParameter(handle))
            .Where(parameter => parameter.SequenceNumber > 0)
            .OrderBy(parameter => parameter.SequenceNumber)
            .Select(parameter => $"{parameter.SequenceNumber}:{reader.GetString(parameter.Name)}")
            .ToArray();
        var signature = method.DecodeSignature(new TypeNameProvider(), genericContext: null);

        Console.WriteLine($"METHOD {methodName} ({string.Join(", ", parameters)}) => {signature.ReturnType} ({string.Join(", ", signature.ParameterTypes)})");
    }
}

return 0;

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
