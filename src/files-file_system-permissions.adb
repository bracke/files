with Files.IO.Fs_Primitives;
with Files.Diagnostics;
with Ada.Strings.Unbounded;

with Hostkit.Metadata;
with Files.File_Identities;
with Files.File_System.Account_Names;
with Files.IO.Errors;

package body Files.File_System.Permissions is

   use Ada.Strings.Unbounded;

   subtype Update_Field is Hostkit.Metadata.Identity_Field;

   --  The one mutation behind Change_Mode, Change_Access and
   --  Change_Ownership: verify the recorded identity (when there is one),
   --  update through the held entry, and report the value it had and the
   --  identity actually changed. A previous value above Max_Previous is
   --  refused rather than truncated. Access_Text and the two access records
   --  are a permission update's, as Hostkit.Metadata.Update_Entry_Metadata
   --  has them.
   function Update_Verified_Entry
     (Path, Expected_Identity : String; Kind : Hostkit.Metadata.Metadata_Update_Kind;
      Value, Group, Max_Previous : Update_Field; Owner_Name, Group_Name, Access_Text : String;
      Previous, Previous_Group : out Update_Field;
      Previous_Access, Applied_Access, Identity : out Files.Types.UString) return Boolean
   is separate;

   function Supports_Permissions return Boolean is separate;

   function Permission_Bits_Of
     (Path      : String;
      Available : out Boolean)
      return Natural is separate;

   function Set_Permissions
     (Path : String;
      Mode : Natural)
      return Mutation_Result
   is separate;

   function Supports_Ownership return Boolean is separate;

   function Change_Access
     (Path, Expected_Identity : String; Mode : Natural; Access_Text : String;
      Previous : out Natural; Previous_Access, Applied_Access, Identity : out Files.Types.UString)
      return Mutation_Result
   is separate;

   function Change_Ownership
     (Path, Expected_Identity : String; User_Id, Group_Id : Files.Types.Account_Id;
      Previous_User, Previous_Group : out Files.Types.Account_Id; Identity : out Files.Types.UString;
      Owner_Name : String := ""; Group_Name : String := "") return Mutation_Result
   is separate;

   function User_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Files.Types.Account_Id is separate;

   function Group_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Files.Types.Account_Id is separate;

   function User_Name_For_Id (Id : Files.Types.Account_Id) return String renames Account_Names.User_Name;

   function Group_Name_For_Id (Id : Files.Types.Account_Id) return String renames Account_Names.Group_Name;

end Files.File_System.Permissions;
