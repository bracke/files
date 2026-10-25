separate (Files.Operations)
--  Split a leaf name for "(copy)" / "(link)" naming. GNAT treats a leading
--  dot as the extension separator (".bashrc" has base "" and extension
--  "bashrc"), which produced " (copy).bashrc"; a leading-dot name has no
--  extension here, matching Files.Paste.
function Leaf_Extension_Start (Name : String) return Natural is
begin
   for Index in reverse Name'Range loop
      if Name (Index) = '.' then
         return (if Index > Name'First and then Index < Name'Last then Index else 0);
      end if;
   end loop;
   return 0;
end Leaf_Extension_Start;
