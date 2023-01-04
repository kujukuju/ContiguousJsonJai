
json_write :: (object: $T, $output_constants: bool = true, $write_null_pointers: bool = false) -> string {
    builder: String_Builder;

    #insert #run get_output_string(T, output_constants, write_null_pointers);

    return builder_to_string(*builder);
}

#scope_file

get_output_string :: (t: Type, output_constants: bool, write_null_pointers: bool) -> string {
    info := cast(*Type_Info) t;
    array_info := cast(*Type_Info_Array) t;

    builder: *String_Builder;

    if info.type == .STRUCT {

    } else if info.type == .POINTER {

    } else if info.type == .ARRAY && array_info.array_type == .RESIZABLE {

    } else if info.type == .ARRAY && array_info.array_type == .FIXED {

    } else if info.type == .STRING {

    } else if info.type == .INTEGER || info.type == .ENUM {

    } else if info.type == .FLOAT {

    } else if info.type == .BOOL {

    } else {
        
    }
}
