separate (Files.Images)
function Image_Bytes_Extent
  (Data   : Ada.Streams.Stream_Element_Array;
   Width  : out Natural;
   Height : out Natural)
   return Boolean
is
begin
   Width := 0;
   Height := 0;
   declare
      W, H : Natural;
   begin
      if not PNG_Header (Data, W, H) then
         return False;
      end if;
      --  A declared dimension is not a promise. Refuse anything that could not
      --  be an image before a caller allocates four bytes per pixel for it.
      if W = 0
        or else H = 0
        or else W > 16_384
        or else H > 16_384
        or else W > Max_Source_Pixels / H
      then
         return False;
      end if;

      Width := W;
      Height := H;
      return True;
   end;
exception
   when others =>
      Width := 0;
      Height := 0;
      return False;
end Image_Bytes_Extent;
