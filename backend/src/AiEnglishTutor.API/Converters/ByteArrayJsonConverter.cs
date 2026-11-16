using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace AiEnglishTutor.API.Converters
{
    public class ByteArrayJsonConverter : JsonConverter<byte[]>
    {
        public override byte[]? Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        {
            if (reader.TokenType == JsonTokenType.Null)
            {
                return null;
            }

            if (reader.TokenType == JsonTokenType.String)
            {
                return reader.GetBytesFromBase64();
            }

            if (reader.TokenType == JsonTokenType.StartArray)
            {
                var byteList = new List<byte>();
                while (reader.Read())
                {
                    if (reader.TokenType == JsonTokenType.EndArray)
                    {
                        break;
                    }

                    if (reader.TokenType == JsonTokenType.Number)
                    {
                        byteList.Add(reader.GetByte());
                    }
                    else
                    {
                        throw new JsonException($"Expected number in byte array, got {reader.TokenType}.");
                    }
                }
                return byteList.ToArray();
            }

            throw new JsonException($"Unexpected token type {reader.TokenType} when deserializing byte[].");
        }

        public override void Write(Utf8JsonWriter writer, byte[] value, JsonSerializerOptions options)
        {
            writer.WriteBase64StringValue(value);
        }
    }
}
