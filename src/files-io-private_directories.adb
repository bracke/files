with Ada.Directories;
with Files.IO.Errors;
with Hostkit.Private_Paths;

package body Files.IO.Private_Directories is
   function Try_Create (Path : String) return Create_Result is
   begin
      Files.IO.Errors.Clear_Os_Error;
      case Hostkit.Private_Paths.Create_Directory (Path) is
         when Hostkit.Private_Paths.Created =>
            return Created;
         when Hostkit.Private_Paths.Already_Exists =>
            return Collision;
         when Hostkit.Private_Paths.Create_Error =>
            Files.IO.Errors.Capture;
            raise Ada.Directories.Use_Error;
      end case;
   end Try_Create;

   procedure Create (Path : String) is
   begin
      if Try_Create (Path) = Collision then
         raise Ada.Directories.Use_Error;
      end if;
   end Create;

   procedure Ensure (Path : String) is
   begin
      Files.IO.Errors.Clear_Os_Error;
      if not Hostkit.Private_Paths.Ensure_Directory (Path) then
         Files.IO.Errors.Capture;
         raise Ada.Directories.Use_Error;
      end if;
   end Ensure;

   procedure Make_File_Private (Descriptor : GNAT.OS_Lib.File_Descriptor) is
   begin
      Files.IO.Errors.Clear_Os_Error;
      if not Hostkit.Private_Paths.Restrict_Open_File (Integer (Descriptor)) then
         --  This refusal's own reason, zero included (a host that gives
         --  none), before the caller's clean-up can overwrite errno: never
         --  one recorded earlier.
         Files.IO.Errors.Adopt_Code (GNAT.OS_Lib.Errno);
         raise Ada.Directories.Use_Error;
      end if;
   end Make_File_Private;
end Files.IO.Private_Directories;
