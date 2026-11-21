with Files.File_System.Trash;
with Files.Protocol_Names;
with Files.Diagnostics;
with Files.Hex_Text;
with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Files.File_System;
with Files.IO.Fs_Primitives;
with Files.Localization;
with Hostkit.Fs;

package body Files.Recovery_CLI is
   use Ada.Strings.Unbounded;

   --  Whether the command being run failed; Run_If_Requested turns it into
   --  the exit status.
   Command_Failed : Boolean := False;

   --  Whether '\' is a character of a name here (it separates on Windows).
   function Backslash_Is_Text return Boolean is (Hostkit.Fs.Separator /= '\');

   function Escaped (Text : String) return String is
      Result : Unbounded_String;
   begin
      for C of Text loop
         case C is
            when ASCII.HT => Append (Result, "\t");
            when ASCII.LF => Append (Result, "\n");
            when ASCII.CR => Append (Result, "\r");
            when Character'Val (0) .. Character'Val (8) | Character'Val (11) | Character'Val (12)
               | Character'Val (14) .. Character'Val (31) | Character'Val (127) =>
               Append (Result, "\x");
               Append (Result, Files.Hex_Text.Byte_Lower (Character'Pos (C)));
            when '\' =>
               Append (Result, (if Backslash_Is_Text then "\\" else "\"));
            when others => Append (Result, C);
         end case;
      end loop;
      return To_String (Result);
   end Escaped;

   function Unescaped (Text : String) return String is
      Result : Unbounded_String;
      Index  : Integer := Text'First;

      function Digit (C : Character) return Integer renames Files.Hex_Text.Digit_Value;

      --  The byte an escape at Index stands for, and how long it is; Width
      --  0 when none starts there.
      procedure Decode (Value : out Character; Width : out Natural) is
         Next : constant Character := Text (Index + 1);
      begin
         Width := 2;
         case Next is
            when 't' =>
               Value := ASCII.HT;
            when 'n' =>
               Value := ASCII.LF;
            when 'r' =>
               Value := ASCII.CR;
            when '\' =>
               Value := '\';
            when 'x' =>
               if Index + 3 <= Text'Last
                 and then Digit (Text (Index + 2)) >= 0 and then Digit (Text (Index + 3)) >= 0
               then
                  Value := Character'Val (Digit (Text (Index + 2)) * 16 + Digit (Text (Index + 3)));
                  Width := 4;
               else
                  Value := ' ';
                  Width := 0;
               end if;
            when others =>
               Value := ' ';
               Width := 0;
         end case;
      end Decode;
   begin
      --  On Windows '\' separates and no name holds a control byte, so the
      --  list printed every path as it is.
      if not Backslash_Is_Text then
         return Text;
      end if;
      while Index <= Text'Last loop
         declare
            Value : Character := Text (Index);
            Width : Natural := 1;
         begin
            if Text (Index) = '\' and then Index < Text'Last then
               Decode (Value, Width);
               if Width = 0 then
                  Value := Text (Index);
                  Width := 1;
               end if;
            end if;
            Append (Result, Value);
            Index := Index + Width;
         end;
      end loop;
      return To_String (Result);
   end Unescaped;

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
         Stage : constant String := Hostkit.Fs.Join (Files.IO.Fs_Primitives.Full_Name (Directory), Name);
      begin
         if Name'Length >= Prefix'Length
           and then Name (Name'First .. Name'First + Prefix'Length - 1) = Prefix
           and then Files.IO.Fs_Primitives.Directory_Exists (Stage)
         then
            declare
               Payload  : constant String := Hostkit.Fs.Join (Stage, Files.Protocol_Names.Stage_Payload);
               Original : constant String := Files.File_System.Trash.Trash_Original_Path (Payload);
            begin
               if Files.File_System.Is_Recovery_Payload (Payload) and then Original /= "" then
                  Ada.Text_IO.Put_Line (Escaped (Payload) & ASCII.HT & Escaped (Original));
               end if;
            end;
         end if;
      end Show;
   begin
      if Hostkit.Fs.Is_Link (Directory)
        or else not Files.IO.Fs_Primitives.Directory_Exists (Directory)
      then
         Fail (Files.Localization.Text ("cli.recovery.error.not_directory") & ':' & ' ' & Directory);
         return;
      end if;
      Files.IO.Fs_Primitives.For_Each_Name (Directory, Show'Access);
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
              (Escaped (Path) & ASCII.HT & Escaped (Files.File_System.Trash.Trash_Original_Path (Path)));
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
           (if Restore then Files.File_System.Trash.Restore_From_Trash (Path)
            else Files.File_System.Trash.Delete_Trashed_Item (Path));
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
         --  A path pasted from the list is read as the list printed it.
         Apply
           ((if Files.File_System.Is_Recovery_Payload (Argument (2)) then Argument (2)
             else Unescaped (Argument (2))),
            Restore => Argument (1) = "--recover");
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
