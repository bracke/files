with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

package body Files.Settings.Open_Actions is
   use Ada.Strings.Unbounded;

   function Trim (Text : String) return String renames Files.Types.Trim_Blanks;

   function Contains (Text : String; Pattern : String) return Boolean is
     (Ada.Strings.Fixed.Index (Text, Pattern) > 0);

   --  The placeholders an argument may be, each standing for the whole
   --  argument: Is_Whole_Placeholder, Contains_Known_Placeholder and
   --  Expand_Placeholders all go by this one list.
   type Placeholder is (Path_Placeholder, Parent_Placeholder, Name_Placeholder, Stem_Placeholder,
                        Extension_Placeholder);

   type Placeholder_Text is access constant String;

   Placeholder_Texts : constant array (Placeholder) of Placeholder_Text :=
     [Path_Placeholder      => new String'("{path}"),
      Parent_Placeholder    => new String'("{parent}"),
      Name_Placeholder      => new String'("{name}"),
      Stem_Placeholder      => new String'("{stem}"),
      Extension_Placeholder => new String'("{extension}")];

   function Is_Whole_Placeholder (Text : String) return Boolean is
     (for some Item of Placeholder_Texts => Text = Item.all);

   function Contains_Known_Placeholder (Text : String) return Boolean is
     (for some Item of Placeholder_Texts => Contains (Text, Item.all));

   function Has_Embedded_Placeholder
     (Argument : String)
      return Boolean
   is
   begin
      return Contains_Known_Placeholder (Argument)
        and then not Is_Whole_Placeholder (Argument);
   end Has_Embedded_Placeholder;

   function Has_Embedded_Placeholder
     (Action : Open_Action)
      return Boolean
   is
   begin
      for Argument of Action.Arguments loop
         if Has_Embedded_Placeholder (To_String (Argument)) then
            return True;
         end if;
      end loop;

      return False;
   end Has_Embedded_Placeholder;

   function Has_Unsafe_Placeholder_Usage
     (Action : Open_Action)
      return Boolean is
   begin
      return Contains_Known_Placeholder (To_String (Action.Executable))
        or else Has_Embedded_Placeholder (Action);
   end Has_Unsafe_Placeholder_Usage;

   --  Build an Open_Action that defers to the host system's default opener.
   --  Returns Found => False when no opener can be located, so callers can
   --  still surface the original "missing open action" diagnostic.
   --
   --  On Linux/Unix the wrapper sidesteps xdg-open's DE-specific routing
   --  (kde-open5 / kde-open6 fail on Qt6-only systems where qtpaths has been
   --  superseded by qtpaths6) by doing the MIME → .desktop → launch dance
   --  itself via xdg-mime + gio launch / gtk-launch, both of which are
   --  Qt-independent. It falls back to xdg-open only when those aren't
   --  available.
   function System_Default_Opener_Action
     (Filetype : String) return Action_Lookup_Result
 is separate;

   function Lookup_Open_Action
     (Settings  : Settings_Model;
      Filetype  : String;
      Modifiers : Guikit.Input.Modifier_Set)
      return Action_Lookup_Result
 is separate;

   function Make_Action
     (Executable : String;
      Arguments  : String_Vectors.Vector;
      Use_Shell  : Boolean := False)
      return Open_Action is
   begin
      return
        (Executable => To_Unbounded_String (Executable),
         Arguments  => Arguments,
         Use_Shell  => Use_Shell,
         others     => <>);
   end Make_Action;

   function Expand_Placeholders
     (Action : Open_Action;
      Path   : String)
      return Open_Action
 is separate;

end Files.Settings.Open_Actions;
