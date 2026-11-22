--  What the suite reaches of Files.Desktop_Applications that is not part of its interface.
package Files.Desktop_Applications.Testing is

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

   --  The open action that runs Action inside the terminal emulator
   --  Terminal (Hostkit.Process.Default_Terminal names one): the terminal's
   --  program, its way of being handed a program to run
   --  (Hostkit.Process.Terminal_Program_Prefix: -e for most, -- for
   --  gnome-terminal and foot, -x for xfce4-terminal and terminator, start --
   --  for wezterm, none for kitty and Windows Terminal, /k for cmd), then
   --  Action's executable and arguments, as arguments of their own.
   --
   --  @param Action The command to run; a shell command line is not wrapped.
   --  @param Terminal The terminal's program, by name or path.
   --  @return The wrapped action; one with no executable when there is no
   --          terminal, or it has no known way to be handed a program and its
   --          arguments (PowerShell, macOS `open`, a terminal Hostkit does
   --          not list).
   function In_Terminal
     (Action   : Files.Settings.Open_Action;
      Terminal : String)
      return Files.Settings.Open_Action;

   --  A BCP 47 locale tag as a Desktop Entry spells a locale postfix:
   --  lang_COUNTRY@MODIFIER. A script that glibc names by a modifier becomes
   --  it (Latn -> latin, Cyrl -> cyrillic, Deva -> devanagari); any other
   --  script is left out, as entries name Chinese by country alone (zh-Hant-TW
   --  -> zh_TW).
   --
   --  @param Tag A canonical locale tag ("sr-Latn-RS", "de-AT", "fi").
   --  @return Its Desktop Entry spelling ("sr_RS@latin", "de_AT", "fi").
   function Desktop_Entry_Locale (Tag : String) return String;

end Files.Desktop_Applications.Testing;
