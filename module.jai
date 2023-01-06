#module_parameters(ASM := true, ASSERT := false);

JsonObject :: struct {
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
        object: JsonObjectEntries;
        array: JsonObjectArray;
        integer: s64;
        number: float64;
        boolean: bool;
        str: string;
    };
}

JsonObjectEntries :: struct {
    entries: [..] JsonObjectEntry;
}

JsonObjectEntry :: struct {
    name: string;
    value: JsonObject;
}

JsonObjectArray :: struct {
    entries: [..] JsonObject;
}

operator [] :: (map: JsonObjectEntries, name: string) -> *JsonObject {
    for i: 0..map.count - 1 {
        if map.entries[i].name == name {
            return *map.entries[i];
        }
    }

    return null;
}

operator [] :: (map: JsonObjectEntries, name: *u8) -> *JsonObject {
    for i: 0..map.count - 1 {
        if memcmp(map.entries[i].name, name, mape[i].count) == 0 {
            return *map.entries[i];
        }
    }

    return null;
}

operator [] :: (map: *JsonObjectEntries, name: string) -> *JsonObject {
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

operator [] :: (map: *JsonObjectEntries, name: *u8) -> *JsonObject {
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
    `return info.type == .STRUCT && t != JsonObject;
}

modify_require_enum :: (t: Type) #expand {
    `info := cast(*Type_Info) t;
    `return info.type == .ENUM;
}

modify_require_array_reject_fixed_array :: (t: Type) #expand {
    `info := cast(*Type_Info_Array) t;
    `return info.type == .ARRAY && info.array_type != .FIXED;
}

#load "reader.jai";
#load "writer.jai";