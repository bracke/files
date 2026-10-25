separate (Files.File_System)
function U32_BE_From
  (Data  : Thumbnail_Byte_Vectors.Vector;
   Index : Natural)
   return Natural
is
   use type Interfaces.Unsigned_32;
   Value : constant Interfaces.Unsigned_32 :=
     Interfaces.Unsigned_32 (Byte_At (Data, Index)) * 16#1000000#
     + Interfaces.Unsigned_32 (Byte_At (Data, Index + 1)) * 16#10000#
     + Interfaces.Unsigned_32 (Byte_At (Data, Index + 2)) * 16#100#
     + Interfaces.Unsigned_32 (Byte_At (Data, Index + 3));
begin
   --  Compute in Unsigned_32 (modular, no overflow) and clamp: a crafted
   --  PNG length/dimension with the high bit set exceeds Natural'Last, and
   --  the old Natural arithmetic overflowed into a Constraint_Error.
   --  Callers reject the resulting too-large dimension anyway.
   return Natural (Interfaces.Unsigned_32'Min (Value, Interfaces.Unsigned_32 (Natural'Last)));
end U32_BE_From;
