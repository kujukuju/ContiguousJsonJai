#import "Basic";
#import "Compiler";
#import "File_Utilities";
#import "String";

build :: () {
    context.allocator = __temporary_allocator;

    current_workspace := get_current_workspace();
    set_build_options_dc(.{do_output = false}, current_workspace);

    workspace := compiler_create_workspace("Contiguous Json Examples");
    build_options := get_build_options(workspace);
    build_options.output_type = .EXECUTABLE;
    build_options.output_executable_name = "run";
    build_options.backend = .LLVM;
    build_options.optimization_level = .RELEASE;
    set_optimization_level(*build_options, 3, 0);

    build_options.import_path = .["C:/jai/modules", #run tprint("%../../", #filepath), "/usr/jai/modules"];
    print("Module folders: %\n", build_options.import_path);
    set_build_options(build_options, workspace);
    set_working_directory(#filepath);

    compiler_begin_intercept(workspace);
    defer compiler_end_intercept(workspace);

    // source files
    add_build_file(tprint("%example.jai", #filepath), workspace);
}

#run build();
