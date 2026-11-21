package body Files.Job_Storage is

   --  Written once while Files.File_System's body elaborates, before any
   --  task that uses them exists; read afterwards only.
   Staging_Remover   : Delete_Operation := null;
   Transport_Remover : Delete_Operation := null;
   Creation_Matcher  : Creation_Check := null;
   Revision_Reader   : Revision_Query := null;
   pragma Atomic (Staging_Remover);
   pragma Atomic (Transport_Remover);
   pragma Atomic (Creation_Matcher);
   pragma Atomic (Revision_Reader);

   procedure Install
     (Delete_Staging   : not null Delete_Operation;
      Delete_Transport : not null Delete_Operation;
      Matches          : not null Creation_Check;
      Revision         : not null Revision_Query) is
   begin
      Staging_Remover := Delete_Staging;
      Transport_Remover := Delete_Transport;
      Creation_Matcher := Matches;
      Revision_Reader := Revision;
   end Install;

   function Delete_Staging_Entry (Path, Expected_Identity : String) return Boolean is
      Operation : constant Delete_Operation := Staging_Remover;
   begin
      if Operation = null then
         raise Program_Error with "Files.Job_Storage: file system operations not installed";
      end if;
      return Operation (Path, Expected_Identity);
   end Delete_Staging_Entry;

   function Delete_Transport_Entry (Path, Expected_Identity : String) return Boolean is
      Operation : constant Delete_Operation := Transport_Remover;
   begin
      if Operation = null then
         raise Program_Error with "Files.Job_Storage: file system operations not installed";
      end if;
      return Operation (Path, Expected_Identity);
   end Delete_Transport_Entry;

   function Creation_Matches
     (Path, Identity, Tree_Revision : String;
      Retain_Verified : Boolean := False) return Boolean
   is
      Operation : constant Creation_Check := Creation_Matcher;
   begin
      if Operation = null then
         raise Program_Error with "Files.Job_Storage: file system operations not installed";
      end if;
      return Operation (Path, Identity, Tree_Revision, Retain_Verified);
   end Creation_Matches;

   function Tree_Revision (Path : String) return String is
      Operation : constant Revision_Query := Revision_Reader;
   begin
      if Operation = null then
         raise Program_Error with "Files.Job_Storage: file system operations not installed";
      end if;
      return Operation (Path);
   end Tree_Revision;

end Files.Job_Storage;
