#module_parameters(ASM := true, VALIDATE := false);

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

modify_require_struct :: (t: Type) #expand {
    `info := cast(*Type_Info) t;
    `return info.type == .STRUCT;
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