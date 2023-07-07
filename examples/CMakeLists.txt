function(add_example example_name)
    add_executable(${example_name}
        ${example_name}/${example_name}.mm
    )

    target_link_libraries(${example_name}
        NSEGL
    )
endfunction()

add_example(context_creation)
