FUNCTION read_mat_element_memory, element_tag_in, $
                                  raw_data_in, $
                                  mem_read_ptr, $
                                  output_var_name, $
                                  SWAP_ENDIAN = swap_endian, $
                                  DEBUG=debug

    data_symbol = element_tag_in.data_symbol
    data_size_bytes = element_tag_in.number_of_bytes
    output_var_name = ''

    IF keyword_set(debug) THEN BEGIN
        print
        print, '** Reading data of type ' + data_symbol + ', size: ', $
               data_size_bytes
               
    ENDIF

    SWITCH data_symbol OF

        'miUTF8':
        'miUTF16':
        'miUTF32':
        'miINT8':
        'miUINT8':
        'miINT16':
        'miUINT16':
        'miINT32':
        'miUINT32':
        'miSINGLE':
        'miDOUBLE':
        'miINT64':
        'miUINT64': begin
            
            data_type_size_bytes = load_mat_size_of_data_type(data_symbol)
            data_type_idl = mat_type_to_idl(data_symbol)            
            number_of_elements = data_size_bytes / data_type_size_bytes
            
            if data_size_bytes gt 0 then begin
            
                data_out = fix(raw_data_in, $
                               mem_read_ptr, $
                               number_of_elements, $
                               TYPE = data_type_idl)
                
                mem_read_ptr = mem_read_ptr + data_size_bytes
                
                IF swap_endian THEN swap_endian_inplace, data_out
                
            endif else begin
                
                ; empty string
                
                data_out = ''
                
            endelse
            
            skip_padding_bytes_memory, mem_read_ptr, DEBUG=debug
            
            break 
        end
        

        'miMATRIX' : BEGIN

            ; Array flags subelement tag

            IF keyword_set(debug) THEN BEGIN
                print
                print, '* Array flags subelement tag'
            ENDIF

            array_flags_tag = element_tag_struct()
            
            read_element_tag_memory, raw_data_in, $
                                     mem_read_ptr, $
                                     array_flags_tag, $
                                     SWAP_ENDIAN=swap_endian, $
                                     DEBUG=debug

            ; Array flags subelement data

            IF keyword_set(debug) THEN BEGIN
                print
                print, '* Array flags subelement data'
            ENDIF

            array_flags_data = subelement_array_flags_struct()
            
            read_subelement_array_flags_memory, raw_data_in, $
                                                mem_read_ptr, $
                                                array_flags_data, $
                                                SWAP_ENDIAN=swap_endian, $
                                                DEBUG=debug
                                         
            matrix_class = array_flags_data.class_symbol
            chk_complex = array_flags_data.complex eq 1

            ;; Dimensions array subelement

            IF keyword_set(debug) THEN BEGIN
                print
                print, '* Dimensions array subelement tag'
            ENDIF

            dimensions_array_tag = element_tag_struct()
            
            read_element_tag_memory, raw_data_in, $
                                     mem_read_ptr, $
                                     dimensions_array_tag, $
                                     SWAP_ENDIAN=swap_endian, $
                                     DEBUG=debug


            IF keyword_set(debug) THEN BEGIN
                print
                print, '* Dimensions array subelement data'
            ENDIF

            dimensions_array_data = subelement_dimensions_array_struct()
            
            read_subelement_dimensions_array_memory, raw_data_in, $
                                                     mem_read_ptr, $
                                                     dimensions_array_tag, $
                                                     dimensions_array_data, $
                                                     SWAP_ENDIAN=swap_endian, $
                                                     DEBUG=debug

            out_ndims = dimensions_array_data.number_of_dimensions
            out_dims  = dimensions_array_data.dimensions[0:out_ndims-1]

            ;; Array name subelement

            IF keyword_set(debug) THEN BEGIN
                print
                print, '* Array name subelement tag'
            ENDIF

            array_name_tag = element_tag_struct()
            
            read_element_tag_memory, raw_data_in, $
                                     mem_read_ptr, $
                                     array_name_tag, $
                                     SWAP_ENDIAN=swap_endian, $
                                     DEBUG=debug

            IF keyword_set(debug) THEN BEGIN
                print
                print, '* Array name subelement data'
            ENDIF

            array_name = ''
            read_subelement_array_name_memory, raw_data_in, $
                                               mem_read_ptr, $ 
                                               array_name_tag, $
                                               array_name, $
                                               SWAP_ENDIAN=swap_endian, $
                                               DEBUG=debug

            total_elements = product(out_dims, /INTEGER)

            case matrix_class of
                
                'mxCELL_CLASS': begin
                    
                    ; we will import the cell array as an array of pointers
                    
                    if total_elements gt 0 then begin
                        
                        tmp_ptr_arr = ptrarr(total_elements)
                        
                        for i = 0, total_elements-1 do begin
                            
                            IF keyword_set(debug) THEN BEGIN
                                print
                                print, '* Cell subelement tag'
                            ENDIF
                            
                            cell_element_tag = element_tag_struct()
                            
                            read_element_tag_memory, raw_data_in, $
                                                     mem_read_ptr, $
                                                     cell_element_tag, $
                                                     SWAP_ENDIAN=swap_endian, $
                                                     DEBUG=debug
                            
                            IF keyword_set(debug) THEN BEGIN
                                print
                                print, '* Cell subelement data'
                            ENDIF
                            
                            cell_data = read_mat_element_memory(cell_element_tag, $
                                                        raw_data_in, $
                                                        mem_read_ptr, $
                                                        output_var_name, $
                                                        SWAP_ENDIAN=swap_endian, $
                                                        DEBUG=debug)
                            
                            tmp_ptr_arr[i] = ptr_new(cell_data, /NO_COPY)
                            
                        endfor
                        
                        ; reform the pointer array to have the correct dimensions,
                        ; and prevent 1x1 arrays from being created
                        
                        if size(tmp_ptr_arr, /N_ELEMENTS) eq 1 then begin
                            
                            data_out = tmp_ptr_arr[0]
                            
                        endif else begin
                            
                            data_out = reform(reform(tmp_ptr_arr, $
                                                     out_dims, $
                                                     /overwrite))
                            
                        endelse
                        
                    endif else begin
                        
                        ; zero length array of cells
                        
                        data_out = ''
                        
                    endelse
                        
                end
                
                'mxSTRUCT_CLASS': begin
                    
                    ; read the field name length subelement
                    
                    IF keyword_set(debug) THEN BEGIN
                        print
                        print, '* Struct subelement tag'
                    ENDIF
                    
                    field_name_length_tag = element_tag_struct()
                    
                    read_element_tag_memory, raw_data_in, $
                                             mem_read_ptr, $
                                             field_name_length_tag, $
                                             SWAP_ENDIAN=swap_endian, $
                                             DEBUG=debug
                    
                    IF keyword_set(debug) THEN BEGIN
                        print
                        print, '* Struct field length data'
                    ENDIF
                    
                    read_subelement_field_length_memory, raw_data_in, $
                                                     mem_read_ptr, $
                                                     field_name_length_tag, $
                                                     field_length, $   
                                                     SWAP_ENDIAN=swap_endian, $
                                                     DEBUG=debug
                    
                    IF keyword_set(debug) THEN BEGIN
                        print
                        print, '* Struct field names tag'
                    ENDIF
                    
                    field_names_data_tag = element_tag_struct()
                    
                    read_element_tag_memory, raw_data_in, $
                                             mem_read_ptr, $
                                             field_names_data_tag, $
                                             SWAP_ENDIAN=swap_endian, $
                                             DEBUG=debug
                    
                    IF keyword_set(debug) THEN BEGIN
                        print
                        print, '* Struct field names data'
                    ENDIF
                    
                    read_subelement_field_names_memory, raw_data_in, $
                                                     mem_read_ptr, $
                                                     field_names_data_tag, $
                                                     field_length, $   
                                                     field_names_arr, $
                                                     SWAP_ENDIAN=swap_endian, $
                                                     DEBUG=debug
                               
                                                    
                    n_fields = N_elements(field_names_arr)
                    
                    for j = 0, total_elements-1 do begin
                    
                        for i = 0, n_fields-1 do begin
                            
                            IF keyword_set(debug) THEN BEGIN
                                print
                                print, '* Struct field name tag: ', $
                                       field_names_arr[i]
                            ENDIF
                            
                            field_element_tag = element_tag_struct()
                            
                            read_element_tag_memory, raw_data_in, $
                                                     mem_read_ptr, $
                                                     field_element_tag, $
                                                     SWAP_ENDIAN=swap_endian, $
                                                     DEBUG=debug
                            
                            IF keyword_set(debug) THEN BEGIN
                                print
                                print, '* Struct field name data: ', $
                                       field_names_arr[i]
                            ENDIF
                            
                            field_data = read_mat_element_memory(field_element_tag,$
                                                        raw_data_in, $
                                                        mem_read_ptr, $
                                                        output_var_name, $
                                                        SWAP_ENDIAN=swap_endian, $
                                                        DEBUG=debug)
                            
                            ; build the structure
                            
                            if i eq 0 then begin
                                
                                tmp_struct = create_struct(field_names_arr[i], $
                                                           field_data)
                                
                            endif else begin
                                
                                tmp_struct = create_struct(tmp_struct, $
                                                           field_names_arr[i], $
                                                           field_data)
                                
                            endelse
                            
                        endfor
                        
                        ; build the structure array 
                        
                        if j eq 0 then begin
                            
                            tmp_str_array = replicate(tmp_struct, $
                                                      total_elements)
                                
                        endif else begin
                            
                            tmp_str_array[j] = tmp_struct
                            
                        endelse
                        
                    endfor
                    
                    ; reform the structure array to have the correct dimensions,
                    ; and prevent 1x1 arrays from being created
                    
                    if size(tmp_str_array, /N_ELEMENTS) eq 1 then begin
                        
                        data_out = tmp_str_array[0]
                        
                    endif else begin
                        
                        data_out = reform(reform(tmp_str_array, $
                                                 out_dims, $
                                                 /overwrite))
                        
                    endelse
                    
                end
                
                
                'mxOBJECT_CLASS': begin
                    
                    message, 'Object data is type not supported'            
                    
                end
                
                'mxSPARSE_CLASS': begin

                    message, 'Sparse array data type is not supported'                    

                end
                
                else: begin
                   
                    ; numeric or character array 
                    
                    ;; Real part (pr) subelement
        
                    IF keyword_set(debug) THEN BEGIN
                        print
                        print, '* Real part subelement tag'
                    ENDIF
        
                    real_part_tag = element_tag_struct()
                    
                    read_element_tag_memory, raw_data_in, $
                                             mem_read_ptr, $
                                             real_part_tag, $
                                             SWAP_ENDIAN=swap_endian, $
                                             DEBUG=debug
        
                    IF keyword_set(debug) THEN BEGIN
                        print
                        print, '* Real part subelement data'
                    ENDIF
        
                    real_data = read_mat_element_memory(real_part_tag, $
                                                    raw_data_in, $
                                                    mem_read_ptr, $
                                                    output_var_name, $
                                                    SWAP_ENDIAN=swap_endian, $
                                                    DEBUG=debug)

                    ; cast the data to its matlab type
                    
                    tmp_dat = load_mat_cast_to_matrix_type(real_data,matrix_class)
        
                    IF chk_complex THEN BEGIN
        
                        ;; Imaginary part (pi) subelement
        
                        IF keyword_set(debug) THEN BEGIN
                            print
                            print, '* Imaginary part subelement tag'
                        ENDIF
        
                        imag_part_tag = element_tag_struct()
                        
                        read_element_tag_memory, raw_data_in, $
                                                 mem_read_ptr, $
                                                 imag_part_tag, $
                                                 SWAP_ENDIAN=swap_endian, $
                                                 DEBUG=debug
        
                        IF keyword_set(debug) THEN BEGIN
                            print
                            print, '* Imaginary part subelement data'
                        ENDIF
        
                        imag_data = read_mat_element_memory(imag_part_tag, $
                                                    raw_data_in, $
                                                    mem_read_ptr, $
                                                    output_var_name, $
                                                    SWAP_ENDIAN=swap_endian, $
                                                    DEBUG=debug)
        
                        tmp_idat = load_mat_cast_to_matrix_type(imag_data,matrix_class)
        
                        if matrix_class eq 'mxDOUBLE_CLASS' then begin
                            
                            chk_dcomplex = 1
                            
                        endif else begin
                            
                            chk_dcomplex = 0
                            
                        endelse
        
                        tmp_dat = complex(temporary(tmp_dat), $
                                          temporary(tmp_idat), $
                                          DOUBLE=chk_dcomplex)
        
                    ENDIF
        

                    ; prevent 1x1 arrays from being created
                    
                    if size(tmp_dat, /N_ELEMENTS) eq 1 then begin
                        
                        data_out = tmp_dat[0]
                        
                    endif else begin
                        
                        data_out = reform(reform(tmp_dat, out_dims, /overwrite))
                        
                    endelse
        
                end
                
            endcase

            output_var_name = array_name
            
            break
        END



        'miCOMPRESSED': begin
            
            message, 'Encountered miCOMPRESSED data in memory stream'
            
            break 
        end

    ENDSWITCH


    return, data_out


END
