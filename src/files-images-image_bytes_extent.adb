separate (Files.Images)
function Image_Bytes_Extent
  (Data   : Ada.Streams.Stream_Element_Array;
   Width  : out Natural;
   Height : out Natural)
   return Boolean
is
   use type Ada.Streams.Stream_Element;
   use type Ada.Streams.Stream_Element_Offset;

   --  PNG: the 8-byte signature (PNG_Magic), then IHDR's length and type,
   --  then width and height as big-endian 32-bit values at offsets 16 and 20.

   function U32_At (Offset : Ada.Streams.Stream_Element_Offset) return Natural is
     (Natural (Data (Data'First + Offset)) * 16#100_0000#
      + Natural (Data (Data'First + Offset + 1)) * 16#1_0000#
      + Natural (Data (Data'First + Offset + 2)) * 16#100#
      + Natural (Data (Data'First + Offset + 3)));
begin
   Width := 0;
   Height := 0;

   if Data'Length < 24 then
      return False;
   end if;

   if Ada.Streams."/=" (Data (Data'First .. Data'First + PNG_Magic'Length - 1), PNG_Magic) then
      return False;
   end if;

   declare
      W : constant Natural := U32_At (16);
      H : constant Natural := U32_At (20);
   begin
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
