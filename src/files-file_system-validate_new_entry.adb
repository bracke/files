separate (Files.File_System)
function Validate_New_Entry
  (Path      : String;
   Empty_Key : String;
   Storable  : Boolean := False)
   return Mutation_Result
is
   Parent : constant String := Parent_Directory (Path);
   Name   : constant String := Mutation_Leaf_Name (Path);
begin
   if Path = "" then
      return (Success => False, Error_Key => To_Unbounded_String (Empty_Key));
   elsif not (if Storable then Storable_Leaf_Name_At (Name, Parent) else Valid_Leaf_Name_At (Name, Parent)) then
      return (Success => False, Error_Key => To_Unbounded_String ("error.name.invalid"));
   elsif Files.Fs_Primitives.Entry_Exists (Path) then
      return (Success => False, Error_Key => To_Unbounded_String ("error.file.exists"));
   elsif Parent = ""
     or else not Ada.Directories.Exists (Parent)
     or else Ada.Directories.Kind (Parent) /= Ada.Directories.Directory
   then
      return (Success => False, Error_Key => To_Unbounded_String ("error.file.parent_missing"));
   end if;
   return (Success => True, Error_Key => Null_Unbounded_String);
end Validate_New_Entry;
