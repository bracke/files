separate (Files.Images)
procedure Loader_Size_Prepared
  (Loader : System.Address;
   Width, Height : C_Int;
   Data : System.Address)
is
   Limit_Pointer : constant C_Int_Pointers.Object_Pointer :=
     C_Int_Pointers.To_Pointer (Data);
   Target_Width, Target_Height : C_Int;
begin
   if Limit_Pointer = null
     or else Limit_Pointer.all <= 0
     or else Width <= 0
     or else Height <= 0
   then
      return;
   end if;
   --  Only ever scale down: an image already within the limit decodes at
   --  its own size rather than being blown up to it.
   if Width <= Limit_Pointer.all and then Height <= Limit_Pointer.all then
      return;
   end if;

   if Width >= Height then
      Target_Width := Limit_Pointer.all;
      Target_Height := C_Int'Max
        (1,
         C_Int
           (Long_Long_Integer (Height) * Long_Long_Integer (Limit_Pointer.all)
            / Long_Long_Integer (Width)));
   else
      Target_Height := Limit_Pointer.all;
      Target_Width := C_Int'Max
        (1,
         C_Int
           (Long_Long_Integer (Width) * Long_Long_Integer (Limit_Pointer.all)
            / Long_Long_Integer (Height)));
   end if;
   Loader_Set_Size (Loader, Target_Width, Target_Height);
exception
   --  Never let an Ada exception cross the C callback boundary.
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.Images");
end Loader_Size_Prepared;
