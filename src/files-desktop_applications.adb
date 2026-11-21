with Ada.Strings.Unbounded;
with GNAT.OS_Lib;

with Files.Diagnostics;
with Files.Environment;
with Files.Localization;
with Hostkit.Desktop_Entries;
with Hostkit.Fs;
with Hostkit.Process;
with Files.Settings.Open_Actions;
with Files.Text_Basics;
with Files.Text_Case;

--  The reading of the entries is Hostkit.Desktop_Entries'; what is here is
--  files' side of it: where to look, in which locale, which entries the
--  picker can launch, and the open actions that launch them.
package body Files.Desktop_Applications is
   use Ada.Strings.Unbounded;

   function To_Host (Items : Files.Types.String_Vectors.Vector) return Hostkit.String_Vectors.Vector is
      Result : Hostkit.String_Vectors.Vector;
   begin
      for Item of Items loop
         Result.Append (Item);
      end loop;
      return Result;
   end To_Host;

   function Desktop_Entry_Locale (Tag : String) return String is
      Language : Unbounded_String;
      Country  : Unbounded_String;
      Modifier : Unbounded_String;
      First    : Positive := Tag'First;
      Part     : Natural := 0;
   begin
      for Index in Tag'First .. Tag'Last + 1 loop
         if Index > Tag'Last or else Tag (Index) in '-' | '_' then
            declare
               Subtag : constant String := Tag (First .. Index - 1);
            begin
               Part := Part + 1;
               if Part = 1 then
                  Language := To_Unbounded_String (Subtag);
               elsif Subtag'Length = 4 then
                  --  A script.
                  Modifier :=
                    To_Unbounded_String
                      (if Subtag = "Latn" then "latin"
                       elsif Subtag = "Cyrl" then "cyrillic"
                       elsif Subtag = "Deva" then "devanagari"
                       else "");
               elsif Subtag'Length in 2 | 3 and then Country = "" then
                  --  A region: a country code, or an area number.
                  Country := To_Unbounded_String (Subtag);
               elsif Files.Text_Case.To_Lower_Ascii (Subtag) = "valencia" then
                  --  The one variant Normalize_Locale keeps (ca_ES@valencia
                  --  becomes ca-ES-valencia): back to its POSIX modifier.
                  Modifier := To_Unbounded_String ("valencia");
               end if;
            end;
            First := Index + 1;
         end if;
      end loop;
      return To_String (Language)
        & (if Country = "" then "" else "_" & To_String (Country))
        & (if Modifier = "" then "" else "@" & To_String (Modifier));
   end Desktop_Entry_Locale;

   --  The locale postfixes localized Name and Icon values are matched
   --  against: the interface's own message locale as its variable spells it
   --  (POSIX modifiers kept), else the host's, in desktop-entry spelling.
   function Message_Locale_Candidates return Hostkit.String_Vectors.Vector is
      Variable : constant String := Files.Environment.Message_Locale;
   begin
      return Hostkit.Desktop_Entries.Locale_Candidates
        (if Variable /= "" then Variable else Desktop_Entry_Locale (Files.Localization.System_Locale));
   end Message_Locale_Candidates;

   function Build_Open_Action
     (App     : Application;
      Targets : Files.Types.String_Vectors.Vector)
      return Files.Settings.Open_Action
   is
      Command      : Hostkit.String_Vectors.Vector;
      Target_Field : Boolean;
      Arguments    : Files.Types.String_Vectors.Vector;
   begin
      if not Hostkit.Desktop_Entries.Command_For
        (Exec         => To_String (App.Exec),
         Name         => To_String (App.Name),
         Icon         => To_String (App.Icon),
         Location     => To_String (App.Desktop_File),
         Targets      => To_Host (Targets),
         Command      => Command,
         Target_Field => Target_Field)
      then
         return Files.Settings.Open_Actions.Make_Action ("", Files.Types.String_Vectors.Empty_Vector);
      end if;

      for Position in Command.First_Index + 1 .. Command.Last_Index loop
         Arguments.Append (Command (Position));
      end loop;
      --  A command with no target field is handed the targets after its own
      --  arguments, as the file manager hands them to any program.
      if not Target_Field then
         Arguments.Append_Vector (Targets);
      end if;
      return Files.Settings.Open_Actions.Make_Action (To_String (Command.First_Element), Arguments);
   end Build_Open_Action;

   function Build_Open_Actions
     (App     : Application;
      Targets : Files.Types.String_Vectors.Vector)
      return Open_Action_Vectors.Vector
   is
      Result : Open_Action_Vectors.Vector;
   begin
      if Natural (Targets.Length) > 1 and then Hostkit.Desktop_Entries.Takes_One_Target (To_String (App.Exec)) then
         for Target of Targets loop
            declare
               One_Target : Files.Types.String_Vectors.Vector;
            begin
               One_Target.Append (Target);
               Result.Append (Build_Open_Action (App, One_Target));
            end;
         end loop;
      else
         Result.Append (Build_Open_Action (App, Targets));
      end if;
      return Result;
   end Build_Open_Actions;

   function In_Terminal
     (Action   : Files.Settings.Open_Action;
      Terminal : String)
      return Files.Settings.Open_Action
   is
      Prefix  : Hostkit.String_Vectors.Vector;
      Wrapped : Files.Settings.Open_Action := Action;
      None    : constant Files.Settings.Open_Action := (others => <>);
   begin
      --  A terminal Hostkit has no way to hand a program and its arguments
      --  to (PowerShell, macOS `open`, one it does not know) cannot run
      --  Action, so the entry gets no launch rather than a guessed one.
      if Terminal = ""
        or else Action.Use_Shell
        or else To_String (Action.Executable) = ""
        or else not Hostkit.Process.Terminal_Program_Prefix (Terminal, Prefix)
      then
         return None;
      end if;
      Wrapped.Executable := To_Unbounded_String (Terminal);
      Wrapped.Arguments.Clear;
      for Option of Prefix loop
         Wrapped.Arguments.Append (Option);
      end loop;
      Wrapped.Arguments.Append (Action.Executable);
      Wrapped.Arguments.Append_Vector (Action.Arguments);
      return Wrapped;
   end In_Terminal;

   function Launch_Actions
     (App      : Application;
      Targets  : Files.Types.String_Vectors.Vector;
      Terminal : String)
      return Open_Action_Vectors.Vector
   is
      Actions : constant Open_Action_Vectors.Vector := Build_Open_Actions (App, Targets);
      Result  : Open_Action_Vectors.Vector;
   begin
      for Action of Actions loop
         declare
            Wrapped : Files.Settings.Open_Action :=
              (if App.Terminal then In_Terminal (Action, Terminal) else Action);
         begin
            if To_String (Wrapped.Executable) = "" then
               return Open_Action_Vectors.Empty_Vector;
            end if;
            Wrapped.Working_Directory := App.Working_Directory;
            Result.Append (Wrapped);
         end;
      end loop;
      return Result;
   end Launch_Actions;

   --  Return the list of XDG base data directories to scan, most specific first.
   --  Where the desktop keeps its entries: the host's answer, which its
   --  default opener searches too. A host with none (Windows, macOS) still
   --  has the folders a user exported in XDG_DATA_HOME and XDG_DATA_DIRS
   --  searched -- they meant them, as files honours its other XDG overrides
   --  on every host -- but not the freedesktop defaults.
   function Data_Directories return Files.Types.String_Vectors.Vector is
      Bases : Files.Types.String_Vectors.Vector;

      procedure Append_Base (Value : String) is
      begin
         if Value = "" or else not GNAT.OS_Lib.Is_Absolute_Path (Value) then
            return;
         end if;
         for Existing of Bases loop
            if To_String (Existing) = Value then
               return;
            end if;
         end loop;
         Bases.Append (To_Unbounded_String (Value));
      end Append_Base;

      --  Split on the host's path-list separator: ';' on Windows, where a
      --  ':' belongs to a drive letter ("D:\apps\share").
      procedure Append_List (List : String) is
      begin
         for Entry_Text of Files.Text_Basics.Split_Path_List (List, GNAT.OS_Lib.Path_Separator) loop
            Append_Base (To_String (Entry_Text));
         end loop;
      end Append_List;
   begin
      for Base of Hostkit.Fs.Application_Data_Directories loop
         Append_Base (To_String (Base));
      end loop;
      if Bases.Is_Empty then
         Append_Base (Files.Environment.Value ("XDG_DATA_HOME"));
         Append_List (Files.Environment.Value ("XDG_DATA_DIRS"));
      end if;
      return Bases;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Desktop_Applications");
         return Files.Types.String_Vectors.Empty_Vector;
   end Data_Directories;

   function Comes_Before (Left, Right : Application) return Boolean is
      Left_Name  : constant String :=
        Files.Text_Case.Fold_For_Sort (To_String (Left.Name));
      Right_Name : constant String :=
        Files.Text_Case.Fold_For_Sort (To_String (Right.Name));
   begin
      if Left_Name /= Right_Name then
         return Left_Name < Right_Name;
      elsif Left.Name /= Right.Name then
         return Left.Name < Right.Name;
      else
         return Left.Desktop_File < Right.Desktop_File;
      end if;
   end Comes_Before;

   package Application_Sorting is new Application_Vectors.Generic_Sorting
     ("<" => Comes_Before);

   function Available_Applications return Application_Vectors.Vector is
      Folders   : Hostkit.String_Vectors.Vector;
      Collected : Application_Vectors.Vector;
      --  The terminal a Terminal=true entry would run in, asked of the host
      --  (it looks the candidates up) only when such an entry is met.
      Terminal       : Unbounded_String;
      Terminal_Asked : Boolean := False;

      --  Whether the picker can launch App: a terminal program is offered
      --  only where a terminal can run it.
      function Offered (App : Application) return Boolean is
      begin
         if not App.Terminal then
            return True;
         end if;
         if not Terminal_Asked then
            Terminal := To_Unbounded_String (Hostkit.Process.Default_Terminal);
            Terminal_Asked := True;
         end if;
         declare
            Wrapped : constant Files.Settings.Open_Action :=
              In_Terminal (Build_Open_Action (App, Files.Types.String_Vectors.Empty_Vector), To_String (Terminal));
         begin
            return To_String (Wrapped.Executable) /= "";
         end;
      end Offered;
   begin
      for Base of Data_Directories loop
         Folders.Append (Base & "/applications");
      end loop;

      for Item of Hostkit.Desktop_Entries.Scan
        (Folders, Message_Locale_Candidates, Files.Environment.Value ("XDG_CURRENT_DESKTOP"))
      loop
         declare
            App : constant Application :=
              (Name              => Item.Name,
               Exec              => Item.Exec,
               Icon              => Item.Icon,
               Desktop_File      => Item.Location,
               Terminal          => Item.Terminal,
               Working_Directory => Item.Working_Directory);
         begin
            if Offered (App) then
               Collected.Append (App);
            end if;
         end;
      end loop;

      Application_Sorting.Sort (Collected);
      return Collected;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Desktop_Applications");
         return Application_Vectors.Empty_Vector;
   end Available_Applications;

end Files.Desktop_Applications;
