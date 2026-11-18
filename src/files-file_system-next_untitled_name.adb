separate (Files.File_System)
function Next_Untitled_Name
  (Directory_Path : String)
   return String
is
   --  A name that cannot be looked at raises, and the handler's plain
   --  name is created exclusively: never one in use.
   function Taken (Leaf : String) return Boolean is
     (Files.Fs_Primitives.Is_Taken (Hostkit.Fs.Join (Directory_Path, Leaf)));

begin
   declare
      --  "untitled.txt", then "untitled 2.txt" ... as a paste numbers a name.
      Free : constant String :=
        Files.Leaf_Names.First_Free
          ("untitled", "txt", Files.Leaf_Names.Spaced_Number'Access, Taken'Access,
           Hostkit.Fs.Leaf_Name_Limit_At (Directory_Path));
   begin
      return (if Free = "" then "untitled.txt" else Free);
   end;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return "untitled.txt";
end Next_Untitled_Name;
