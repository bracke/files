with Ada.Containers.Ordered_Maps;
with Ada.Strings.Unbounded;
with Hostkit.Metadata;

package body Files.File_System.Account_Names is
   use Ada.Strings.Unbounded;

   package Id_Name_Maps is new Ada.Containers.Ordered_Maps
     (Key_Type     => Files.Types.Account_Id,
      Element_Type => Unbounded_String,
      "<"          => Hostkit.Metadata."<");

   --  Which account database an id is resolved against.
   type Name_Account is (User_Names, Group_Names);

   --  One session memo per account database.
   Caches : array (Name_Account) of Id_Name_Maps.Map;

   --  The one memoized lookup; Kind picks the database and its memo.
   function Name_For_Id (Kind : Name_Account; Id : Files.Types.Account_Id) return String is
      Cache    : Id_Name_Maps.Map renames Caches (Kind);
      Position : constant Id_Name_Maps.Cursor := Cache.Find (Id);
   begin
      if Id_Name_Maps.Has_Element (Position) then
         return To_String (Id_Name_Maps.Element (Position));
      end if;
      declare
         Name : constant String :=
           (case Kind is
               when User_Names  => Hostkit.Metadata.User_Name_For_Id (Id),
               when Group_Names => Hostkit.Metadata.Group_Name_For_Id (Id));
      begin
         Cache.Insert (Id, To_Unbounded_String (Name));
         return Name;
      end;
   end Name_For_Id;

   function User_Name (Id : Files.Types.Account_Id) return String is (Name_For_Id (User_Names, Id));

   function Group_Name (Id : Files.Types.Account_Id) return String is (Name_For_Id (Group_Names, Id));

end Files.File_System.Account_Names;
