separate (Files.File_System)
function Change_Access
  (Path, Expected_Identity : String; Mode : Natural; Access_Text : String;
   Previous : out Natural; Previous_Access, Applied_Access, Identity : out Files.Types.UString)
   return Mutation_Result
is
   Failed : constant Mutation_Result :=
     (Success => False, Error_Key => To_Unbounded_String ("error.permissions.failed"));
   Old_Mode, Unused_Group : Update_Field;
begin
   Previous := 0;
   Previous_Access := Null_Unbounded_String;
   Applied_Access := Null_Unbounded_String;
   Identity := Null_Unbounded_String;
   if Mode > 8#7777# then
      return Failed;
   end if;
   if not Update_Verified_Entry
     (Path, Expected_Identity, Hostkit.Metadata.Update_Permissions,
      Value => Update_Field (Mode), Group => 0, Max_Previous => Update_Field (Natural'Last),
      Owner_Name => "", Group_Name => "", Access_Text => Access_Text,
      Previous => Old_Mode, Previous_Group => Unused_Group,
      Previous_Access => Previous_Access, Applied_Access => Applied_Access, Identity => Identity)
   then
      return Failed;
   end if;
   Previous := Natural (Old_Mode);
   return (Success => True, Error_Key => Null_Unbounded_String);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return Failed;
end Change_Access;
