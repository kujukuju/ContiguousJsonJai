
json_write :: (object: $T, $output_constants: bool = true, $write_null_pointers: bool = false, $formatted: bool = false) -> string {
    builder: String_Builder;

    write_output(object, *builder, output_constants, write_null_pointers, formatted);

    return builder_to_string(*builder);
}

#scope_file

write_output :: (object: $T, builder: *String_Builder, $output_constants: bool, $write_null_pointers: bool, $formatted: bool) #modify modify_require_struct(T) {
    #insert #run get_struct_string(T, output_constants, write_null_pointers, formatted);
}

write_output :: (object: $T, builder: *String_Builder, $output_constants: bool, $write_null_pointers: bool, $formatted: bool) #modify modify_require_array_reject_fixed_array(T) {
    append(builder, "[");

    // TODO check write_null_pointers here

    for i: 0..object.count - 1 {
        write_output(object[i], builder, output_constants, write_null_pointers, formatted);

        if i < object.count - 1 {
            append(builder, ",");
        }
    }

    append(builder, "]");
}

write_output :: (object: [$N] $T, builder: *String_Builder, $output_constants: bool, $write_null_pointers: bool, $formatted: bool) {
    #insert #run get_fixed_array_string([N] T, output_constants, write_null_pointers, formatted);
}

write_output :: (object: *$T, builder: *String_Builder, $output_constants: bool, $write_null_pointers: bool, $formatted: bool) {
    if object {
        write_output(<< object, builder, output_constants, write_null_pointers, formatted);
    } else {
        append(builder, "null");
    }
}

write_output :: inline (object: $T, builder: *String_Builder, $output_constants: bool, $write_null_pointers: bool, $formatted: bool) #modify modify_require_enum(T) {
    EnumType :: #run (t: Type) -> Type {
        enum_info := (cast(*Type_Info_Enum) T).internal_type;
        if enum_info.signed && enum_info.runtime_size == 1 {
            return s8;
        } else if enum_info.signed && enum_info.runtime_size == 2 {
            return s16;
        } else if enum_info.signed && enum_info.runtime_size == 4 {
            return s32;
        } else if enum_info.signed && enum_info.runtime_size == 8 {
            return s64;
        } else if !enum_info.signed && enum_info.runtime_size == 1 {
            return u8;
        } else if !enum_info.signed && enum_info.runtime_size == 2 {
            return u16;
        } else if !enum_info.signed && enum_info.runtime_size == 4 {
            return u32;
        } else {
            return u64;
        }
    }(T);

    write_output(cast(EnumType) object, builder, output_constants, write_null_pointers, formatted);
}

write_output :: inline (object: float32, builder: *String_Builder, $output_constants: bool, $write_null_pointers: bool, $formatted: bool) {
    print_to_builder(builder, "%", formatFloat(object));
}

write_output :: inline (object: float64, builder: *String_Builder, $output_constants: bool, $write_null_pointers: bool, $formatted: bool) {
    print_to_builder(builder, "%", formatFloat(object));
}

write_output :: inline (object: u8, builder: *String_Builder, $output_constants: bool, $write_null_pointers: bool, $formatted: bool) {
    print_to_builder(builder, "%", formatInt(object));
}

write_output :: inline (object: u16, builder: *String_Builder, $output_constants: bool, $write_null_pointers: bool, $formatted: bool) {
    print_to_builder(builder, "%", formatInt(object));
}

write_output :: inline (object: u32, builder: *String_Builder, $output_constants: bool, $write_null_pointers: bool, $formatted: bool) {
    print_to_builder(builder, "%", formatInt(object));
}

write_output :: inline (object: u64, builder: *String_Builder, $output_constants: bool, $write_null_pointers: bool, $formatted: bool) {
    print_to_builder(builder, "%", formatInt(object));
}

write_output :: inline (object: s8, builder: *String_Builder, $output_constants: bool, $write_null_pointers: bool, $formatted: bool) {
    print_to_builder(builder, "%", formatInt(object));
}

write_output :: inline (object: s16, builder: *String_Builder, $output_constants: bool, $write_null_pointers: bool, $formatted: bool) {
    print_to_builder(builder, "%", formatInt(object));
}

write_output :: inline (object: s32, builder: *String_Builder, $output_constants: bool, $write_null_pointers: bool, $formatted: bool) {
    print_to_builder(builder, "%", formatInt(object));
}

write_output :: inline (object: s64, builder: *String_Builder, $output_constants: bool, $write_null_pointers: bool, $formatted: bool) {
    print_to_builder(builder, "%", formatInt(object));
}

write_output :: inline (object: bool, builder: *String_Builder, $output_constants: bool, $write_null_pointers: bool, $formatted: bool) {
    if object {
        append(builder, "true");
    } else {
        append(builder, "true");
    }
}

write_output :: inline (object: string, builder: *String_Builder, $output_constants: bool, $write_null_pointers: bool, $formatted: bool) {
    append(builder, "\"");
    append(builder, object);
    append(builder, "\"");
}

get_fixed_array_string :: (t: Type, output_constants: bool, write_null_pointers: bool, formatted: bool) -> string {
    array_info := cast(*Type_Info_Array) t;

    // TODO check write_null_pointers here
    
    insert: String_Builder;

    append(*insert, "append(builder, \"[\");\n");

    for i: 0..array_info.array_count - 1 {
        append(*insert, "write_output(object[");
        append(*insert, tprint("%", i));
        append(*insert, "], builder, output_constants, write_null_pointers, formatted);\n");
    }

    append(*insert, "append(builder, \"]\");\n");

    return builder_to_string(*insert);
}

get_struct_string :: (t: Type, output_constants: bool, write_null_pointers: bool, formatted: bool) -> string {
    struct_info := cast(*Type_Info_Struct) t;

    insert: String_Builder;

    append(*insert, "append(builder, \"{\");\n");

    member_count: int;
    for member: struct_info.members {
        if member.offset_into_constant_storage && !output_constants {
            continue;
        }

        if !is_writable_type(<< cast(*Type) *member.type) {
            continue;
        }

        member_count += 1;
    }

    if !write_null_pointers {
        append(*insert, "wrote := false;\n");
    }
    
    index: int;
    for member: struct_info.members {
        if member.offset_into_constant_storage && !output_constants {
            continue;
        }

        if !is_writable_type(<< cast(*Type) *member.type) {
            continue;
        }
        
        member_name := member.name;
        json_name := get_json_name(member_name, member.notes);

        should_check_pointer := member.type.type == .POINTER && !write_null_pointers;

        if should_check_pointer {
            append(*insert, "if object.");
            append(*insert, member_name);
            append(*insert, " {\n");
        }

        if !write_null_pointers {
            // if youre not writing null pointers we have to check writes and add commas before because there's no guarantee where you end
            if index > 0 {
                append(*insert, "if wrote {\n");
                append(*insert, "append(builder, \",\");\n");
                append(*insert, "}\n");
            }
        }

        append(*insert, "append(builder, \"\\\"");
        append(*insert, json_name);
        append(*insert, "\\\":\");\n");
        append(*insert, "write_output(object.");
        append(*insert, member_name);
        append(*insert, ", builder, output_constants, write_null_pointers, formatted);\n");

        if !write_null_pointers {
            append(*insert, "wrote = true;\n");
        }

        if should_check_pointer {
            append(*insert, "}\n");
        }

        if write_null_pointers {
            if index < member_count - 1 {
                append(*insert, "append(builder, \",\");\n");
            }
        }

        index += 1;
    }

    append(*insert, "append(builder, \"}\");\n");

    return builder_to_string(*insert);
}

is_writable_type :: (t: Type) -> bool {
    info := cast(*Type_Info) t;

    writable := false;
    writable = writable || info.type == .INTEGER;
    writable = writable || info.type == .FLOAT;
    writable = writable || info.type == .BOOL;
    writable = writable || info.type == .STRING;
    writable = writable || info.type == .POINTER;
    writable = writable || info.type == .STRUCT;
    writable = writable || info.type == .ARRAY;
    writable = writable || info.type == .ENUM;
    return writable;
}
