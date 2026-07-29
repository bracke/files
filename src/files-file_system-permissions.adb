with Ada.Containers.Ordered_Maps;
with Ada.Strings.Unbounded;
with Files.Fs;
with Files.Platform.Metadata;

separate (Files.File_System)
package body Permissions is

   --  Session cache for numeric-id -> name resolution. Build_Snapshot resolves
   --  the selected items' owner/group names every frame, so memoize each id's
   --  name (including an unresolved "") to avoid repeated getpwuid/getgrgid.
   package Id_Name_Maps is new Ada.Containers.Ordered_Maps
     (Key_Type     => Natural,
      Element_Type => Unbounded_String);
   User_Name_Cache  : Id_Name_Maps.Map;
   Group_Name_Cache : Id_Name_Maps.Map;

   function Supports_Permissions return Boolean is
   begin
      return Files.Platform.Metadata.Permissions_Supported;
   end Supports_Permissions;

   function Permission_Bits_Of
     (Path      : String;
      Available : out Boolean)
      return Natural is
   begin
      return Files.Platform.Metadata.File_Permission_Bits (Path, Available);
   end Permission_Bits_Of;

   function Set_Permissions
     (Path : String;
      Mode : Natural)
      return Mutation_Result
   is
      function Exists_Safely (Candidate : String) return Boolean is
      begin
         return Candidate /= "" and then Files.Fs.Exists (Candidate);
      exception
         when others =>
            return False;
      end Exists_Safely;
   begin
      if not Files.Platform.Metadata.Permissions_Supported then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.permissions.unsupported"));
      elsif not Exists_Safely (Path) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.permissions.failed"));
      elsif Files.Platform.Metadata.Set_Permissions (Path, Mode) then
         return (Success => True, Error_Key => Null_Unbounded_String);
      else
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.permissions.failed"));
      end if;
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.permissions.failed"));
   end Set_Permissions;

   function Supports_Ownership return Boolean is
   begin
      return Files.Platform.Metadata.Ownership_Supported;
   end Supports_Ownership;

   procedure Ownership_Of
     (Path      : String;
      User_Id   : out Natural;
      Group_Id  : out Natural;
      Available : out Boolean) is
   begin
      Files.Platform.Metadata.File_Ownership (Path, User_Id, Group_Id, Available);
   end Ownership_Of;

   function Set_Ownership
     (Path     : String;
      User_Id  : Natural;
      Group_Id : Natural)
      return Mutation_Result
   is
      function Exists_Safely (Candidate : String) return Boolean is
      begin
         return Candidate /= "" and then Files.Fs.Exists (Candidate);
      exception
         when others =>
            return False;
      end Exists_Safely;
   begin
      if not Files.Platform.Metadata.Ownership_Supported then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.ownership.unsupported"));
      elsif not Exists_Safely (Path) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.ownership.denied"));
      elsif Files.Platform.Metadata.Set_Ownership (Path, User_Id, Group_Id) then
         return (Success => True, Error_Key => Null_Unbounded_String);
      else
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.ownership.denied"));
      end if;
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.ownership.denied"));
   end Set_Ownership;

   function User_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Natural is
   begin
      return Files.Platform.Metadata.User_Id_For_Name (Name, Found);
   end User_Id_For_Name;

   function Group_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Natural is
   begin
      return Files.Platform.Metadata.Group_Id_For_Name (Name, Found);
   end Group_Id_For_Name;

   function User_Name_For_Id (Id : Natural) return String is
      Position : constant Id_Name_Maps.Cursor := User_Name_Cache.Find (Id);
   begin
      if Id_Name_Maps.Has_Element (Position) then
         return To_String (Id_Name_Maps.Element (Position));
      end if;
      declare
         Name : constant String := Files.Platform.Metadata.User_Name_For_Id (Id);
      begin
         User_Name_Cache.Insert (Id, To_Unbounded_String (Name));
         return Name;
      end;
   end User_Name_For_Id;

   function Group_Name_For_Id (Id : Natural) return String is
      Position : constant Id_Name_Maps.Cursor := Group_Name_Cache.Find (Id);
   begin
      if Id_Name_Maps.Has_Element (Position) then
         return To_String (Id_Name_Maps.Element (Position));
      end if;
      declare
         Name : constant String := Files.Platform.Metadata.Group_Name_For_Id (Id);
      begin
         Group_Name_Cache.Insert (Id, To_Unbounded_String (Name));
         return Name;
      end;
   end Group_Name_For_Id;

end Permissions;
