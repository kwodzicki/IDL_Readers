FUNCTION TEST_GROUP_DIMS

COMPILE_OPT IDL2

testFile = FILEPATH('ncdf_group_dims_test.nc', ROOT_DIR=!TMP_Data)

oid  = NCDF_CREATE(testFile, /CLOBBER, /NETCDF4_FORMAT)
dim0 = NCDF_DIMDEF(oid, 'top0', 1)

gid0 = NCDF_GROUPDEF(oid, 'group0')
dim1 = NCDF_DIMDEF(gid0, 'group0', 2)

vid = NCDF_VARDEF(gid0, 'testing', [dim1], /float)
NCDF_ATTPUT, gid0, vid, 'scale_factor',  0.01
NCDF_ATTPUT, gid0, vid, 'add_offset',   10.0
NCDF_ATTPUT, gid0, vid, '_FillValue',    0.0

gid1 = NCDF_GROUPDEF(oid, 'group1')
dim1 = NCDF_DIMDEF(gid1, 'group1', 20)

gid2 = NCDF_GROUPDEF(gid1, 'subgroup0')
dim2 = NCDF_DIMDEF(gid2, 'subgroup0', 3)

dim0 = NCDF_DIMDEF(oid, 'top1', 10)

NCDF_CONTROL, oid, /ENDEF

NCDF_VARPUT, gid0, vid, (FINDGEN(2)-10.0) / 0.01
 
NCDF_CLOSE, oid

RETURN, testFile

END
