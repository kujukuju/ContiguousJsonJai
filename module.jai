#module_parameters(ASM := true, ENABLE_ASSERT := true);

JsonGeneric :: struct {
    JsonType :: enum {
        Object;
        Array;
        Integer;
        Float;
        Boolean;
        String;
        Null;
    }

    type: JsonType;
    
    union {
        object: [..] JsonObjectEntry;
        array: [..] JsonGeneric;
        integer: s64;
        number: float64;
        boolean: bool;
        str: string;
    };
}

JsonObjectEntry :: struct {
    name: string;
    value: JsonGeneric;
}

// operator [] :: (generic: JsonGeneric, name: string) -> *JsonGeneric {
//     if generic.type != .Object {
//         return null;
//     }

//     for i: 0..generic.object.count - 1 {
//         if generic.object[i].name == name {
//             return *generic.object[i].value;
//         }
//     }

//     return null;
// }

get :: (generic: JsonGeneric, name: *u8) -> *JsonGeneric {
    if generic.type != .Object {
        return null;
    }

    for i: 0..generic.object.count - 1 {
        if generic.object[i].name == to_string(name) {
            return *generic.object[i].value;
        }
    }

    return null;
}

operator [] :: (generic: JsonGeneric, name: *u8) -> *JsonGeneric {
    return get(generic, name);
}

operator [] :: (generic: *JsonGeneric, name: string) -> *JsonGeneric {
    if generic.type != .Object {
        return null;
    }
    
    for i: 0..generic.object.count - 1 {
        if generic.object[i].name == name {
            return *generic.object[i].value;
        }
    }

    entry := array_add(*generic.object);
    entry.name.data = alloc(name.count);
    memcpy(entry.name.data, name.data, name.count);
    entry.name.count = name.count;

    return *entry.value;
}

operator [] :: (generic: *JsonGeneric, name: *u8) -> *JsonGeneric {
    if generic.type != .Object {
        return null;
    }
    
    for i: 0..generic.object.count - 1 {
        if generic.object[i].name == to_string(name) {
            return *generic.object[i].value;
        }
    }

    name_count := c_style_strlen(name);

    entry := array_add(*generic.object);
    entry.name.data = alloc(name_count);
    memcpy(entry.name.data, name, name_count);
    entry.name.count = name_count;

    return *entry.value;
}

get_json_name :: (member_name: string, notes: [] string) -> string {
    for note: notes {
        if begins_with_nocase(note, "json(") && ends_with_nocase(note, ")") {
            json_name: string;
            json_name.data = note.data + 5;
            json_name.count = note.count - 6;
            return json_name;
        }
    }

    return member_name;
}

ignore_member :: (notes: [] string) -> bool {
    for note: notes {
        if equal_nocase(note, "jsonignore") {
            return true;
        }
    }

    return false;
}

modify_require_struct_reject_json_object :: (t: Type) #expand {
    `info := cast(*Type_Info) t;
    `return info.type == .STRUCT && t != JsonGeneric;
}

modify_require_enum :: (t: Type) #expand {
    `info := cast(*Type_Info) t;
    `return info.type == .ENUM;
}

modify_require_array_reject_fixed_array :: (t: Type) #expand {
    `info := cast(*Type_Info_Array) t;
    `return info.type == .ARRAY && info.array_type != .FIXED;
}

// I never intended to release this code but it's pretty extremely useful for debugging json
json_print :: (value: $T, name: string = "", depth: int = 0) {
    #if #run (cast(*Type_Info) T).type == .POINTER {
        if value {
            json_print(<< value, name, depth);
            return;
        }
    }

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
        if t == JsonGeneric {
            append(*builder, #string DONE
            if value.type == .Object {
                for entry: value.object {
                    json_print(entry.value, entry.name, depth + 1);
                }
            } else if value.type == .Array {
                for i: 0..value.array.count - 1 {
                    json_print(value.array[i], tprint("value[%]", i), depth + 1);
                }
            } else if value.type == .Integer {
                json_print(value.integer, name, depth);
            } else if value.type == .Float {
                json_print(value.number, name, depth);
            } else if value.type == .Boolean {
                json_print(value.boolean, name, depth);
            } else if value.type == .String {
                json_print(value.str, name, depth);
            } else if value.type == .Null {
                json_print(cast(*void) null, name, depth);
            }
            DONE);
        } else if struct_info.type == .STRUCT {
            for member: struct_info.members {
                if member.offset_into_constant_storage >= 0 {
                    continue;
                }

                if member.type.type == .POINTER {
                    append(*builder, "if value.");
                    append(*builder, member.name);
                    append(*builder, " {\n");
                    append(*builder, "json_print(");
                    append(*builder, "<< value.");
                    append(*builder, member.name);
                    append(*builder, ", \"");
                    append(*builder, member.name);
                    append(*builder, "\", depth + 1);\n");
                    append(*builder, "}\n");
                } else {
                    append(*builder, "json_print(");
                    append(*builder, "value.");
                    append(*builder, member.name);
                    append(*builder, ", \"");
                    append(*builder, member.name);
                    append(*builder, "\", depth + 1);\n");
                }
            }
        } else if struct_info.type == .ARRAY {
            append(*builder, "for i: 0..value.count - 1 {\n");
            append(*builder, "json_print(value.data[i], tprint(\"value[%]\", i), depth + 1);\n");
            append(*builder, "};\n");
        }

        return builder_to_string(*builder);
    }(T);

    if depth == 0 {
        print("\n");
    }
}

#load "reader.jai";
#load "writer.jai";