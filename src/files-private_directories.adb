with Ada.Directories;
with Interfaces.C;
with System;

package body Files.Private_Directories is
   function Try_Create (Path : String) return Create_Result is
      use type Interfaces.C.int;
      function Create_Native (Name : System.Address) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_private_directory";
      Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Path);
      Result : constant Interfaces.C.int := Create_Native (Name'Address);
   begin
      if Result = 1 then
         return Created;
      elsif Result = 0 then
         return Collision;
      else
         raise Ada.Directories.Use_Error;
      end if;
   end Try_Create;

   procedure Create (Path : String) is
   begin
      if Try_Create (Path) = Collision then
         raise Ada.Directories.Use_Error;
      end if;
   end Create;
end Files.Private_Directories;
