with Guikit.Input;

--  Open actions: how a file is opened (the action configured for its
--  filetype, the host's opener as fallback), how an action is built, and the
--  placeholders ({path}, {parent}, {name}, {stem}, {extension}) an action's
--  arguments stand for.
package Files.Settings.Open_Actions is

   --  What Lookup_Open_Action found: the action and the token it was
   --  configured under, or the error key saying why there is none.
   type Action_Lookup_Result is record
      Found            : Boolean := False;
      Action           : Open_Action;
      Token            : UString;
      Error_Key        : UString;
      System_Fallback  : Boolean := False;
   end record;

   --  Lookup an open action using full filetype-plus-modifier fallback rules.
   --
   --  @param Settings Settings model to inspect.
   --  @param Filetype Filetype identifier.
   --  @param Modifiers Active modifier set.
   --  @return Lookup result with selected action or localized error key.
   function Lookup_Open_Action
     (Settings  : Settings_Model;
      Filetype  : String;
      Modifiers : Guikit.Input.Modifier_Set)
      return Action_Lookup_Result;

   --  Build an open action value.
   --
   --  @param Executable Executable path or command name.
   --  @param Arguments Action arguments.
   --  @param Use_Shell Whether explicit shell execution is requested.
   --  @return Open action value.
   function Make_Action
     (Executable : String;
      Arguments  : String_Vectors.Vector;
      Use_Shell  : Boolean := False)
      return Open_Action;

   --  Return whether an action uses placeholders outside safe argument slots.
   --
   --  @param Action Open action to inspect.
   --  @return True when the executable contains a placeholder or any argument embeds one.
   function Has_Unsafe_Placeholder_Usage
     (Action : Open_Action)
      return Boolean;

   --  Substitute whole-argument placeholders for a selected file path.
   --
   --  @param Action Open action to expand.
   --  @param Path Full selected file path.
   --  @return Expanded action arguments.
   function Expand_Placeholders
     (Action : Open_Action;
      Path   : String)
      return Open_Action;

private

   --  Return whether Argument contains a placeholder embedded in other text.
   --
   --  @param Argument Open-action argument to inspect.
   --  @return True when a known placeholder is not the whole argument.
   function Has_Embedded_Placeholder
     (Argument : String)
      return Boolean;

   --  Return whether any action argument contains an embedded placeholder.
   --
   --  @param Action Open action to inspect.
   --  @return True when any known placeholder is embedded in other text.
   function Has_Embedded_Placeholder
     (Action : Open_Action)
      return Boolean;

end Files.Settings.Open_Actions;
