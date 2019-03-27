FUNCTION load_mat_cast_to_matrix_type, input_data, matrix_class

    CASE matrix_class OF
        'mxCHAR_CLASS'   : return, string(byte(temporary(input_data)))
        'mxDOUBLE_CLASS' : return, double(temporary(input_data))
        'mxSINGLE_CLASS' : return, float(temporary(input_data))
        'mxINT8_CLASS'   : return, byte(temporary(input_data))
        'mxUINT8_CLASS'  : return, byte(temporary(input_data))
        'mxINT16_CLASS'  : return, fix(temporary(input_data))
        'mxUINT16_CLASS' : return, uint(temporary(input_data))
        'mxINT32_CLASS'  : return, long(temporary(input_data))
        'mxUINT32_CLASS' : return, ulong(temporary(input_data))
        'mxINT64_CLASS'  : return, long64(temporary(input_data))
        'mxUINT64_CLASS' : return, ulong64(temporary(input_data))
    ENDCASE

END
