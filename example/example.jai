main :: () {
    {
        print("Parsing 1.\n");
        result, memory, success := json_parse(JSON_STRING1, JsonType1);
        defer free(memory);
        if success {
            print_anything(result);
        } else {
            print("Unsuccessful 1.\n");
        } 
    }
    // {
    //     print("Parsing 2.\n");
    //     result, memory, success := json_parse(JSON_STRING2, [..] JsonType2Entry);
    //     defer free(memory);
    //     if success {
    //         print_anything(result);
    //     } else {
    //         print("Unsuccessful 2.\n");
    //     }
    // }
    // {
    //     print("Parsing 3.\n");
    //     result, memory, success := json_parse(JSON_STRING3, [2] JsonType3Entry);
    //     defer free(memory);
    //     if success {
    //         print_anything(result);
    //     } else {
    //         print("Unsuccessful 3.\n");
    //     }
    // }
    // {
    //     JSON_STRING :: #string DONE
    //         [-237462374673276894279832749832423479823246327846]
    //     DONE

    //     JsonType :: [..] int;

    //     print("Parsing 4.\n");
    //     result, memory, success := json_parse(JSON_STRING, JsonType);
    //     defer free(memory);
    //     if success {
    //         print_anything(result);
    //     } else {
    //         print("Unsuccessful.\n");
    //     }
    // }
}

print_anything :: (value: $T, name: string = "", depth: int = 0) {
    for i: 0..depth - 1 {
        print("\t");
    }
    if name {
        print("% = %\n", name, value);
    } else {
        print("%\n", value);
    }

    #insert #run (t: Type) -> string {
        builder: String_Builder;

        struct_info := cast(*Type_Info_Struct) t;
        if struct_info.type == .STRUCT {
            for member: struct_info.members {
                if member.offset_into_constant_storage >= 0 {
                    continue;
                }

                if member.type.type == .POINTER {
                    append(*builder, "if value.");
                    append(*builder, member.name);
                    append(*builder, " {\n");
                    append(*builder, "print_anything(");
                    append(*builder, "<< value.");
                    append(*builder, member.name);
                    append(*builder, ", \"");
                    append(*builder, member.name);
                    append(*builder, "\", depth + 1);\n");
                    append(*builder, "}\n");
                } else {
                    append(*builder, "print_anything(");
                    append(*builder, "value.");
                    append(*builder, member.name);
                    append(*builder, ", \"");
                    append(*builder, member.name);
                    append(*builder, "\", depth + 1);\n");
                }
            }
        } else if struct_info.type == .ARRAY {
            append(*builder, "for i: 0..value.count - 1 {\n");
            append(*builder, "print_anything(value[i], tprint(\"value[%]\", i), depth + 1);\n");
            append(*builder, "};\n");
        }

        return builder_to_string(*builder);
    }(T);
}

prints_value1 :: (value: JsonType1) {
    print("value1 % % % % %\n", value, << value.key1, << value.key3, << value.key4.key6, << value.key8);
}

prints_value2 :: (value: [..] JsonType2Entry) {
    print("value2 %\n", value);
}

prints_value3 :: (value: [2] JsonType3Entry) {
    print("value3 %\n", value);
}

JsonType1 :: struct {
    Key4 :: struct {
        key5: float;
        key6: *string;
    };

    // optional
    key1: *string;
    // required
    key2: float;
    // optional
    key3: *[..] float;
    // required
    key4: Key4;
    // optional
    key7: *float;
    // optional
    key8: *float;
}

JsonType2Entry :: struct {
    // required
    number: int;
    // optional
    value: *float;
    // required
    other_number: u32;
    // required
    fourth_number: int;
}

JsonType3Entry :: struct {
    // required
    what: int; @json(number)
    // optional
    value: *float;
    // required
    other_number: u32;
    // required
    fourth_number: int;
    test: string; @json(context)
}

JSON_STRING1 :: #string DONE
{
	"key2": 0.5,
	"key1": "hey",
	"key3": [0.4, 0.6, 0.8, 1.0],
	"key4": {
		"key5": 2.0,
		"key6": "lol"
	},
	"key8": 1.5
}
DONE

JSON_STRING2 :: #string DONE
[
    {
        "number": -4,
        "value": 0.5,
        "other_number": 4,
        "fourth_number": 400
    }, {
        "number": -5,
        "other_number": 5,
        "fourth_number": 500
    }
]
DONE

JSON_STRING3 :: #string DONE
[
    {
        "number": -4,
        "value": 0.5,
        "other_number": 4,
        "fourth_number": 400,
        "context": "context one!"
    }, {
        "number": -5,
        "other_number": 5,
        "fourth_number": 500,
        "context": "context two???\" I escaped a quote"
    }
]
DONE

#import "ContiguousJsonJai"(VALIDATE=true);
#import "Basic";
