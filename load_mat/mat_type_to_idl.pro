FUNCTION mat_type_to_idl, data_symbol

    CASE data_symbol OF
        'miINT8'   : return, 1
        'miUINT8'  : return, 1
        'miUTF8'   : return, 1
        'miINT16'  : return, 2
        'miUINT16' : return, 12
        'miUTF16'  : return, 2
        'miINT32'  : return, 3
        'miUINT32' : return, 13
        'miUTF32'  : return, 3
        'miSINGLE' : return, 4
        'miINT64'  : return, 14 
        'miUINT64' : return, 15 
        'miDOUBLE' : return, 5
    ENDCASE

END
