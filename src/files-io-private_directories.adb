with Ada.Directories;
with Files.Diagnostics;
with Files.IO.Errors;
with Files.Text_Basics;
with Hostkit.Fs;
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

   function Create_Numbered
     (Parent  : String;
      Prefix  : String;
      Reclaim : access function (Path : String) return Boolean := null;
      Prepare : access procedure (Path : String) := null;
      Abandon : access procedure (Path : String) := null)
      return String is
   begin
      for N in 1 .. 9_999 loop
         declare
            Candidate : constant String := Hostkit.Fs.Join (Parent, Prefix & Files.Text_Basics.Natural_Text (N));
         begin
            if Prepare /= null then
               Prepare (Candidate);
            end if;
            begin
               if Try_Create (Candidate) = Created
                 or else (Reclaim /= null
                          and then Reclaim (Candidate)
                          and then Try_Create (Candidate) = Created)
               then
                  return Candidate;
               end if;
            exception
               when others =>
                  --  A refused create (not a collision) ends the search:
                  --  what Prepare published for this candidate goes first.
                  --  The refusal is what is raised: a cleanup the host
                  --  refuses too is traced, never raised in its place.
                  if Abandon /= null then
                     declare
                        Refusal : constant Integer := Files.IO.Errors.Last_Code;
                     begin
                        begin
                           Abandon (Candidate);
                        exception
                           when Swallowed : others =>
                              Files.Diagnostics.Note (Swallowed, "Files.IO.Private_Directories");
                        end;
                        Files.IO.Errors.Adopt_Code (Refusal);
                     end;
                  end if;
                  raise;
            end;
            if Abandon /= null then
               Abandon (Candidate);
            end if;
         end;
      end loop;
      return "";
   end Create_Numbered;

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
