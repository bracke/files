with Ada.Containers.Vectors;

with Files.Settings;
with Files.Types;

--  Discovery of installed desktop applications for the "Open With" picker.
package Files.Applications is
   subtype UString is Files.Types.UString;

   type Application is record
      Name : UString;
      Exec : UString;
   end record;

   package Application_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Application);

   --  Return the installed desktop applications available for "Open With".
   --
   --  On Linux the XDG application directories ($XDG_DATA_HOME or
   --  ~/.local/share, plus each entry of $XDG_DATA_DIRS, defaulting to
   --  /usr/local/share:/usr/share) are scanned for *.desktop entries. Each
   --  entry's [Desktop Entry] group is parsed; entries are skipped when their
   --  Type is not Application, when NoDisplay or Hidden is true, or when Exec is
   --  empty. Desktop Exec field codes are stripped. The result is sorted by Name
   --  (case-insensitive) and deduplicated by Name.
   --
   --  All filesystem access is guarded so a malformed entry is skipped and a
   --  missing directory yields an empty result rather than an exception, which
   --  keeps platforms without XDG application directories (macOS, Windows) safe.
   --
   --  @return Available applications, possibly empty.
   function Available_Applications return Application_Vectors.Vector;

   --  Build the open action that launches an application on the given targets.
   --
   --  The application Exec string is tokenized: the first token is the
   --  executable and the remaining tokens become leading arguments, followed by
   --  one argument per target path. The action is never shell-wrapped.
   --
   --  @param App Application whose Exec string supplies the executable and base
   --  arguments.
   --  @param Targets Target paths appended as trailing arguments.
   --  @return Open action ready to be spawned (detached) by the caller.
   function Build_Open_Action
     (App     : Application;
      Targets : Files.Types.String_Vectors.Vector)
      return Files.Settings.Open_Action;

end Files.Applications;
