main :: () {
    // TODO once floats work perfectly in sync with javascript the tests can be improved by removing whitespaces and comparing strings to the original json

    #insert #run () -> string {
        files := file_list("tests");

        builder: String_Builder;

        for file: files {
            if !ends_with(file, ".jai") {
                continue;
            }

            file_contents := read_entire_file(file);
            append(*builder, tprint(#string DONE
            {
                %
                
                print("Testing %.\n\n");

                start := get_time() * 1000;
                result, memory, success := json_parse(JSON_STRING, JsonType, contiguous_memory = true);
                end := get_time() * 1000;
                defer free(memory);
                if success {
                    print("Succeeded in parsing json.\n");
                    print("Took %% milliseconds.\n\n", end - start);

                    if JSON_STRING.count < 1000 {
                        print("Result:\n");
                        json_print(result);
                    }

                    json := json_write(result);
                    defer free(json);

                    if JSON_STRING.count < 1000 {
                        print("Written:\n");
                        json_print(json);
                    }

                    result2, memory2, success2 := json_parse(json, JsonType, contiguous_memory = true);
                    defer free(memory2);

                    if success2 {
                        json_equal2 := json_write(result2);
                        defer free(json_equal2);

                        if json == json_equal2 {
                            print("Successfully wrote the same json twice.\n\n");
                        } else {
                            print("Failed to write the same json twice.\n\n", to_standard_error = true);
                        }

                        result3, memory3, success3 := json_parse(json, JsonGeneric, contiguous_memory = true);
                        defer free(memory3);

                        if success3 {
                            json_equal3 := json_write(result3);
                            defer free(json_equal3);

                            if json == json_equal3 {
                                print("Successfully wrote the same generic json.\n\n");
                            } else {
                                print("Failed to write the same generic json. Possibly because of float32 vs float64.\n\n", to_standard_error = true);
                            }
                        }
                    }
                } else {
                    print("Failed to parse.\n", to_standard_error = true);
                }

                print("---\n\n");
            }
            DONE, file_contents, file));
        }

        return builder_to_string(*builder);
    }();
}

#import "ContiguousJsonJai"(ASSERT = false);
#import "Basic";
#import "File_Utilities";
#import "File";
#import "String";