separate (Files.Operations)
function Leaf_Extension (Name : String) return String is
   Dot : constant Natural := Leaf_Extension_Start (Name);
begin
   return (if Dot = 0 then "" else Name (Dot + 1 .. Name'Last));
end Leaf_Extension;
