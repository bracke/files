separate (Files.File_System)
--  Shared destination validation for the create-link commands: the new link
--  path must be a valid, currently-unused leaf inside an existing directory.
function Validate_Link_Destination
  (Link_Path : String)
   return Mutation_Result
is
   Parent : constant String := Parent_Directory (Link_Path);
   Name   : constant String := Mutation_Leaf_Name (Link_Path);
begin
   if Link_Path = "" then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.link.failed"));
   elsif not Storable_Leaf_Name_At (Name, Parent) then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.name.invalid"));
   elsif Ada.Directories.Exists (Link_Path) or else Hostkit.Fs.Is_Link (Link_Path) then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.file.exists"));
   elsif Parent = ""
     or else not Ada.Directories.Exists (Parent)
     or else Ada.Directories.Kind (Parent) /= Ada.Directories.Directory
   then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.file.parent_missing"));
   end if;

   return (Success => True, Error_Key => Null_Unbounded_String);
end Validate_Link_Destination;
