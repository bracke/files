with Files.Protocol_Names;
with Files.Diagnostics;
with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Files.File_System;
with Files.Fs_Primitives;
with Files.Localization;
with Hostkit.Fs;

package body Files.Recovery_CLI is
   use Ada.Strings.Unbounded;

   --  Whether the command being run failed; Run_If_Requested turns it into
   --  the exit status.
   Command_Failed : Boolean := False;

   procedure Fail (Message : String) is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Message);
      Command_Failed := True;
   end Fail;

   procedure List (Directory : String) is
      Prefix : constant String := Files.Protocol_Names.Recovery_Stage_Prefix;

      procedure Show (Name : String; Stop : in out Boolean) is
         pragma Unreferenced (Stop);
         --  Absolute, however the folder was named on the command line.
         Stage : constant String := Hostkit.Fs.Join (Files.Fs_Primitives.Full_Name (Directory), Name);
      begin
         if Name'Length >= Prefix'Length
           and then Name (Name'First .. Name'First + Prefix'Length - 1) = Prefix
           and then Files.Fs_Primitives.Directory_Exists (Stage)
         then
            declare
               Payload  : constant String := Hostkit.Fs.Join (Stage, "payload");
               Original : constant String := Files.File_System.Trash_Original_Path (Payload);
            begin
               if Files.File_System.Is_Recovery_Payload (Payload) and then Original /= "" then
                  Ada.Text_IO.Put_Line (Payload & ASCII.HT & Original);
               end if;
            end;
         end if;
      end Show;
   begin
      if Hostkit.Fs.Is_Link (Directory)
        or else not Files.Fs_Primitives.Directory_Exists (Directory)
      then
         Fail (Files.Localization.Text ("cli.recovery.error.not_directory") & ':' & ' ' & Directory);
         return;
      end if;
      Files.Fs_Primitives.For_Each_Name (Directory, Show'Access);
   exception
      when Failure : others =>
         Files.Diagnostics.Note (Failure, "Files.Recovery_CLI");
         Fail (Files.Localization.Text ("cli.recovery.error.list") & ':' & ' ' & Directory);
   end List;

   procedure List_Registered is
      Payloads : Files.Types.String_Vectors.Vector;
   begin
      --  Finish interrupted work first, so the list shows what is left.
      Files.File_System.Sweep_Recovery_Registry;
      Payloads := Files.File_System.Registered_Recovery_Payloads;
      for Payload of Payloads loop
         declare
            Path : constant String := To_String (Payload);
         begin
            Ada.Text_IO.Put_Line
              (Path & ASCII.HT & Files.File_System.Trash_Original_Path (Path));
         end;
      end loop;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Recovery_CLI");
         Fail (Files.Localization.Text ("cli.recovery.error.list_all"));
   end List_Registered;

   procedure Apply (Path : String; Restore : Boolean) is
   begin
      if not Files.File_System.Is_Recovery_Payload (Path) then
         Fail (Files.Localization.Text ("cli.recovery.error.not_payload") & ':' & ' ' & Path);
         return;
      end if;
      declare
         Result : constant Files.File_System.Mutation_Result :=
           (if Restore then Files.File_System.Restore_From_Trash (Path)
            else Files.File_System.Delete_Trashed_Item (Path));
      begin
         if not Result.Success then
            Fail (Files.Localization.Text (To_String (Result.Error_Key)) & ": " & Path);
         end if;
      end;
   end Apply;

   function Run
     (Arguments : Files.Types.String_Vectors.Vector;
      Failed    : out Boolean) return Boolean
   is
      Count : constant Natural := Natural (Arguments.Length);

      function Argument (Index : Positive) return String is
        (To_String (Arguments (Arguments.First_Index + Index - 1)));
   begin
      Command_Failed := False;
      Failed := False;
      if Count = 0 then
         return False;
      elsif Argument (1) not in "--list-recoveries" | "--recover" | "--discard-recovery" then
         return False;
      elsif Argument (1) = "--list-recoveries" then
         if Count = 1 then
            List_Registered;
         elsif Count = 2 then
            List (Argument (2));
         else
            Fail (Files.Localization.Text ("cli.recovery.error.list_argument"));
         end if;
      elsif Count /= 2 then
         Fail (Files.Localization.Text ("cli.recovery.error.argument"));
      else
         Apply (Argument (2), Restore => Argument (1) = "--recover");
      end if;
      Failed := Command_Failed;
      return True;
   end Run;

   function Run_If_Requested return Boolean is
      Arguments : Files.Types.String_Vectors.Vector;
      Failed    : Boolean;
   begin
      for Index in 1 .. Ada.Command_Line.Argument_Count loop
         Arguments.Append (To_Unbounded_String (Ada.Command_Line.Argument (Index)));
      end loop;
      return Handled : constant Boolean := Run (Arguments, Failed) do
         if Failed then
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         end if;
      end return;
   end Run_If_Requested;
end Files.Recovery_CLI;
