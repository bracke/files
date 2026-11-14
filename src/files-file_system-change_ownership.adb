separate (Files.File_System)
function Change_Ownership
  (Path, Expected_Identity : String; User_Id, Group_Id : Files.Types.Account_Id;
   Previous_User, Previous_Group : out Files.Types.Account_Id; Identity : out Files.Types.UString;
   Owner_Name : String := ""; Group_Name : String := "") return Mutation_Result
is
   Failed : constant Mutation_Result :=
     (Success => False, Error_Key => To_Unbounded_String ("error.ownership.denied"));
   use type Files.Types.Account_Id;
   Old_User, Old_Group : Update_Field;
   Unused_Previous_Access, Unused_Applied_Access : Files.Types.UString;
begin
   declare
      Watch : constant Ownership_Hook := Before_Ownership_Change;
   begin
      if Watch /= null then
         Watch (Path, User_Id, Group_Id);
      end if;
   end;
   Previous_User := 0;
   Previous_Group := 0;
   Identity := Null_Unbounded_String;
   if not Update_Verified_Entry
     (Path, Expected_Identity, Hostkit.Metadata.Update_Ownership,
      --  Keep_Id becomes Keep_Id_Field: that id is left as it is.
      Value =>
        (if User_Id = Hostkit.Metadata.Keep_Id then Hostkit.Metadata.Keep_Id_Field else Update_Field (User_Id)),
      Group =>
        (if Group_Id = Hostkit.Metadata.Keep_Id then Hostkit.Metadata.Keep_Id_Field else Update_Field (Group_Id)),
      Max_Previous => Update_Field (Files.Types.Account_Id'Last),
      --  A kept id (Hostkit.Metadata.Keep_Id) names no account.
      Owner_Name =>
        (if Owner_Name /= "" then Owner_Name
         elsif User_Id = Hostkit.Metadata.Keep_Id then ""
         else User_Name_For_Id (User_Id)),
      Group_Name =>
        (if Group_Name /= "" then Group_Name
         elsif Group_Id = Hostkit.Metadata.Keep_Id then ""
         else Group_Name_For_Id (Group_Id)),
      Access_Text => "",
      Previous => Old_User, Previous_Group => Old_Group,
      Previous_Access => Unused_Previous_Access, Applied_Access => Unused_Applied_Access,
      Identity => Identity)
   then
      return Failed;
   end if;
   Previous_User := Files.Types.Account_Id (Old_User);
   Previous_Group := Files.Types.Account_Id (Old_Group);
   return (Success => True, Error_Key => Null_Unbounded_String);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return Failed;
end Change_Ownership;
