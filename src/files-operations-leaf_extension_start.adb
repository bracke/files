separate (Files.Operations)
--  Split a leaf name for "(copy)" / "(link)" naming: Files.Types' one rule
--  (".bashrc" is all name, unlike GNAT's Base_Name).
function Leaf_Extension_Start (Name : String) return Natural is
begin
   return Files.Types.Extension_Start (Name);
end Leaf_Extension_Start;
