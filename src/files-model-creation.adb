with Files.Model.Support;

package body Files.Model.Creation is

   use Files.Model.Support;
   use Ada.Strings.Unbounded;

   procedure Begin_Create_File
      (Model : in out Window_Model;
       Name  : String) is
   begin
      Touch (Model);
      Begin_Create_Temporary (Model, Name, Is_Directory => False);
   end Begin_Create_File;

   procedure Begin_Create_Folder
      (Model : in out Window_Model;
       Name  : String) is
   begin
      Touch (Model);
      Begin_Create_Temporary (Model, Name, Is_Directory => True);
   end Begin_Create_Folder;

   function Temporary_Item_Is_Active
     (Model : Window_Model)
      return Boolean is
     (Model.Temporary.Active);

   function Temporary_Item_Is_Directory
     (Model : Window_Model)
      return Boolean is
     (Model.Temporary.Is_Directory);

   function Temporary_Item_Name
     (Model : Window_Model)
      return String is
     (To_String (Model.Temporary.Name));

end Files.Model.Creation;
