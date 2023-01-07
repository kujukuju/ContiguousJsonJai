#module_parameters(ASM := true, ASSERT := false);

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
        object: JsonObject;
        array: [..] JsonGeneric;
        integer: s64;
        number: float64;
        boolean: bool;
        str: string;
    };
}

JsonObject :: struct {
    entries: [..] JsonObjectEntry;
}

JsonObjectEntry :: struct {
    name: string;
    value: JsonGeneric;
}

operator [] :: (map: JsonObject, name: string) -> *JsonGeneric {
    for i: 0..map.count - 1 {
        if map.entries[i].name == name {
            return *map.entries[i];
        }
    }

    return null;
}

operator [] :: (map: JsonObject, name: *u8) -> *JsonGeneric {
    for i: 0..map.count - 1 {
        if memcmp(map.entries[i].name, name, mape[i].count) == 0 {
            return *map.entries[i];
        }
    }

    return null;
}

operator [] :: (map: *JsonObject, name: string) -> *JsonGeneric {
    for i: 0..map.count - 1 {
        if memcmp(map.entries[i].name, name, mape[i].count) == 0 {
            return *map.entries[i];
        }
    }

    entry := array_add(*map.entries);
    entry.name.data = alloc(name.count);
    memcpy(entry.name.data, name.data, entry.count);
    entry.name.count = name.count;

    return array_add(map);
}

operator [] :: (map: *JsonObject, name: *u8) -> *JsonGeneric {
    for i: 0..map.count - 1 {
        if memcmp(map.entries[i].name, name, mape[i].count) == 0 {
            return *map.entries[i];
        }
    }

    name_count := c_style_strlen(name);

    entry := array_add(map.entries);
    entry.name.data = alloc(name_count);
    memcpy(entry.name.data, name, entry.count);
    entry.name.count = name_count;

    return entry;
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
                for entry: value.object.entries {
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