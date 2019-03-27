FUNCTION GOESR_LATLON, x, y, goes_proj
;+
; Name:
;   GOESR_LATLON 
; Purpose:
;   An IDL function to compute latitude/longitude values for
;   goes r data.
; See https://www.goes-r.gov/products/docs/PUG-L2+-vol5.pdf
;
COMPILE_OPT IDL2
dims = [N_ELEMENTS(x), N_ELEMENTS(y)]
x = REBIN(x, dims)
y = REBIN(REFORM(y, 1, dims[1]), dims)

H = goes_proj.PERSPECTIVE_POINT_HEIGHT + goes_proj.SEMI_MAJOR_AXIS
aa = COS(y)^2+(goes_proj.SEMI_MAJOR_AXIS/goes_proj.SEMI_MINOR_AXIS)^2*SIN(y)^2

a  = SIN(x)^2 + COS(x)^2 * aa
b  = -2*H*COS(x)*COS(y)
c  = H^2 - goes_proj.SEMI_MAJOR_AXIS^2

rs = (-b - SQRT(b^2-4*a*c)) / 2 / a

sx =  rs * COS(x) * COS(y)
sy = -rs * SIN(X)
sz = rs * COS(x) * SIN(y)

num = goes_proj.SEMI_MAJOR_AXIS^2 * sz
den = goes_proj.SEMI_MINOR_AXIS^2 * SQRT( (H-sx)^2 + sy^2 )
lat = ATAN(num, den) * !RTOD
lon = ATAN(sy, H - sx) * !RTOD
lon = goes_proj.LONGITUDE_OF_PROJECTION_ORIGIN - lon

RETURN, {LON : lon, LAT : lat}
END