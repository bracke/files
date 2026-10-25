separate (Files.File_System)
function Image_Bytes_Extent
  (Data   : Ada.Streams.Stream_Element_Array;
   Width  : out Natural;
   Height : out Natural)
   return Boolean
is
   use type Ada.Streams.Stream_Element;
   use type Ada.Streams.Stream_Element_Offset;

   --  PNG: an 8-byte signature, then IHDR's length and type, then width and
   --  height as big-endian 32-bit values at fixed offsets 16 and 20.
   Signature : constant Ada.Streams.Stream_Element_Array (0 .. 7) :=
     [16#89#, 16#50#, 16#4E#, 16#47#, 16#0D#, 16#0A#, 16#1A#, 16#0A#];

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

   for Index in Signature'Range loop
      if Data (Data'First + Index) /= Signature (Index) then
         return False;
      end if;
   end loop;

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
