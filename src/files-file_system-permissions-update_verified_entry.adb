separate (Files.File_System.Permissions)
function Update_Verified_Entry
  (Path, Expected_Identity : String; Kind : Hostkit.Metadata.Metadata_Update_Kind;
   Value, Group, Max_Previous : Update_Field; Owner_Name, Group_Name, Access_Text : String;
   Previous, Previous_Group : out Update_Field;
   Previous_Access, Applied_Access, Identity : out Files.Types.UString) return Boolean
is
   subtype U64 is Update_Field;
   use type U64;
   Expected : Hostkit.Metadata.Entry_Identity;
   Updated  : Hostkit.Metadata.Metadata_Update_Result;

begin
   Previous := 0;
   Previous_Group := 0;
   Previous_Access := Null_Unbounded_String;
   Applied_Access := Null_Unbounded_String;
   Identity := Null_Unbounded_String;
   if Expected_Identity /= ""
     and then not Files.File_Identities.Parse (Expected_Identity, Expected)
   then
      return False;
   end if;
   Updated := Hostkit.Metadata.Update_Entry_Metadata
     (Path           => Path,
      Expected       => Expected,
      Check_Expected => Expected_Identity /= "",
      Kind           => Kind,
      Value          => Value,
      Group          => Group,
      Max_Previous   => Max_Previous,
      Owner_Name     => Owner_Name,
      Group_Name     => Group_Name,
      Access_Text    => Access_Text);
   if not Updated.Success
     or else Updated.Previous > Max_Previous
     or else Updated.Previous_Group > Max_Previous
   then
      return False;
   end if;
   Previous := Updated.Previous;
   Previous_Group := Updated.Previous_Group;
   Previous_Access := Updated.Previous_Access;
   Applied_Access := Updated.Applied_Access;
   Identity := To_Unbounded_String (Files.File_Identities.Image (Updated.Identity));
   return True;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return False;
end Update_Verified_Entry;
