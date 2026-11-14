package body Files.File_System.Permissions is

   function Supports_Permissions return Boolean
     renames Files.File_System.Supports_Permissions;

   function Permission_Bits_Of
     (Path      : String;
      Available : out Boolean)
      return Natural
     renames Files.File_System.Permission_Bits_Of;

   function Set_Permissions
     (Path : String;
      Mode : Natural)
      return Mutation_Result
     renames Files.File_System.Set_Permissions;

   function Supports_Ownership return Boolean
     renames Files.File_System.Supports_Ownership;

   function Change_Access
     (Path, Expected_Identity : String; Mode : Natural; Access_Text : String;
      Previous : out Natural; Previous_Access, Applied_Access, Identity : out Files.Types.UString)
      return Mutation_Result
     renames Files.File_System.Change_Access;

   function Change_Ownership
     (Path, Expected_Identity : String; User_Id, Group_Id : Files.Types.Account_Id;
      Previous_User, Previous_Group : out Files.Types.Account_Id; Identity : out Files.Types.UString;
      Owner_Name : String := ""; Group_Name : String := "") return Mutation_Result
     renames Files.File_System.Change_Ownership;

   function User_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Files.Types.Account_Id
     renames Files.File_System.User_Id_For_Name;

   function Group_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Files.Types.Account_Id
     renames Files.File_System.Group_Id_For_Name;

   function User_Name_For_Id (Id : Files.Types.Account_Id) return String
     renames Files.File_System.User_Name_For_Id;

   function Group_Name_For_Id (Id : Files.Types.Account_Id) return String
     renames Files.File_System.Group_Name_For_Id;

end Files.File_System.Permissions;
