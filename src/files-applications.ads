with Ada.Containers.Vectors;

with Files.Settings;
with Files.Types;

--  Discovery of installed desktop applications for the "Open With" picker.
package Files.Applications is
   subtype UString is Files.Types.UString;

   type Application is record
      Name         : UString;
      Exec         : UString;
      Icon         : UString;
      Desktop_File : UString;
   end record;

   package Application_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Application);

   package Open_Action_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Files.Settings.Open_Action,
      "="          => Files.Settings."=");

   --  Return the installed desktop applications available for "Open With".
   --
   --  On Linux the XDG application directories ($XDG_DATA_HOME or
   --  ~/.local/share, plus each entry of $XDG_DATA_DIRS, defaulting to
   --  /usr/local/share:/usr/share) are scanned for *.desktop entries. Relative
   --  XDG paths are ignored as invalid. Each
   --  entry's [Desktop Entry] group is parsed; entries are skipped when their
   --  Type is not Application, when NoDisplay or Hidden is true, when TryExec is
   --  unavailable, when the current desktop is excluded, or when Exec is empty.
   --  Escapes and separators in OnlyShowIn/NotShowIn string lists are parsed, and
   --  the two keys may coexist when their desktop-name sets do not overlap.
   --  Malformed desktop Exec command lines are skipped. Entries are resolved by
   --  desktop-file ID in XDG directory precedence order, including hidden entries
   --  that mask lower-priority definitions. Localized Name and Icon values use
   --  the current message locale's fallback order, and desktop string escapes are
   --  decoded before Exec quoting. Invalid boolean values, malformed lines and
   --  group headers, duplicate keys or groups, and localized values without their
   --  required base keys are rejected. The result is sorted by Name
   --  (case-insensitive); distinct applications may share a Name.
   --
   --  All filesystem access is guarded so a malformed entry is skipped and a
   --  missing directory yields an empty result rather than an exception, which
   --  keeps platforms without XDG application directories (macOS, Windows) safe.
   --
   --  @return Available applications, possibly empty.
   function Available_Applications return Application_Vectors.Vector;

   --  Build the open action that launches an application on the given targets.
   --
   --  The application Exec string is parsed using desktop-entry quoting and
   --  escaping rules. File field codes retain their argument position; %c, %i,
   --  %k and %% are expanded without passing through a shell. Targets are
   --  appended when the command contains no file field code.
   --
   --  @param App Application whose Exec string supplies the executable and base
   --  arguments.
   --  @param Targets Target paths appended as trailing arguments.
   --  @return Open action ready to be spawned (detached) by the caller.
   function Build_Open_Action
     (App     : Application;
      Targets : Files.Types.String_Vectors.Vector)
      return Files.Settings.Open_Action;

   --  Build every launch required by an application's desktop Exec line.
   --
   --  A single-target %f or %u field produces one action per selected target;
   --  %F and %U produce one action containing the complete target list. Commands
   --  without a target field retain the file manager's trailing-target behavior.
   --
   --  @param App Application whose Exec string supplies the launch template.
   --  @param Targets Selected paths to open.
   --  @return One or more actions in launch order.
   function Build_Open_Actions
     (App     : Application;
      Targets : Files.Types.String_Vectors.Vector)
      return Open_Action_Vectors.Vector;

end Files.Applications;
