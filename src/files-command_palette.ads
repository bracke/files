with Ada.Containers.Vectors;

with Files.Commands;
with Files.Model;
with Files.Types;

--  Command-palette filtering over registered commands.
package Files.Command_Palette is
   subtype UString is Files.Types.UString;

   --  A palette result represents either a registered command (the default) or,
   --  when Is_Application is True, an installed application offered by the
   --  "Open With" picker. Application results carry their Name and Exec so the
   --  controller can build and spawn an open action; their Command stays
   --  No_Command.
   type Result_Entry is record
      Command        : Files.Commands.Command_Id := Files.Commands.No_Command;
      Identifier     : UString;
      Label          : UString;
      Description    : UString;
      Enabled        : Boolean := False;
      Score          : Natural := 0;
      Is_Application  : Boolean := False;
      Application_Name : UString;
      Application_Exec : UString;
   end record;

   package Result_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Result_Entry);

   --  Search command-palette entries by localized label, description,
   --  shortcut text, or stable identifier.
   --
   --  @param Query Search text.
   --  @param Model Current model used for enablement.
   --  @return Palette results in registry order for an empty query and by
   --  relevance score for a non-empty query.
   function Search
     (Query : String;
      Model : Files.Model.Window_Model)
      return Result_Vectors.Vector;

end Files.Command_Palette;
