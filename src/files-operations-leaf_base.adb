separate (Files.Operations)
function Leaf_Base (Name : String) return String is
   Dot : constant Natural := Leaf_Extension_Start (Name);
begin
   return (if Dot = 0 then Name else Name (Name'First .. Dot - 1));
end Leaf_Base;
