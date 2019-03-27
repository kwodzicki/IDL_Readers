FUNCTION load_mat_size_of_data_type, data_symbol

    SWITCH data_symbol OF
        'miINT8'   :
        'miUINT8'  :
        'miUTF8'   : return, 1
        'miINT16'  :
        'miUINT16' :
        'miUTF16'  : return, 2
        'miINT32'  :
        'miUINT32' :
        'miUTF32'  :
        'miSINGLE' : return, 4
        'miINT64'  :
        'miUINT64' :
        'miDOUBLE' : return, 8
    ENDSWITCH

END
