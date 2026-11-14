package body Files.Settings.Open_Actions.Testing is

   function Has_Embedded_Placeholder
     (Argument : String)
      return Boolean
     renames Files.Settings.Open_Actions.Has_Embedded_Placeholder;

   function Has_Embedded_Placeholder
     (Action : Open_Action)
      return Boolean
     renames Files.Settings.Open_Actions.Has_Embedded_Placeholder;

end Files.Settings.Open_Actions.Testing;
