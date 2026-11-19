with Files.Model.Command_Palette;
with Files.Model.Root_Selector;
with Files_Suite.Support.Disk;
with Files_Suite.Support.Models;
separate (Files_Suite.Model)
   --  Every "is an overlay open" question reads Files.Model's one list of
   --  input-owning overlays: the overlay's own click handler excludes itself,
   --  and typed characters reach the palette's query once it covers the
   --  selector, but nothing while it covers it unfocused.
   procedure Test_Overlay_Queries (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
      Roots : Files.Types.String_Vectors.Vector;
   begin
      Assert (not Files.Model.Input_Owning_Overlay_Is_Open (Model), "no overlay is open at first");
      Assert (not Files.Model.Character_Input_Is_Contained (Model), "nothing owns native input at first");
      for Overlay in Files.Model.Input_Overlay loop
         Assert (not Files.Model.Testing.Overlay_Is_Open (Model, Overlay), "no single overlay is open at first");
      end loop;

      Roots.Append (Ada.Strings.Unbounded.To_Unbounded_String (Files_Suite.Support.Disk.Root));
      Files.Model.Root_Selector.Open (Model, Roots);
      Assert
        (Files.Model.Testing.Overlay_Is_Open (Model, Files.UI_Types.Root_Selector_Overlay), "the selector is open");
      Assert (Files.Model.Input_Owning_Overlay_Is_Open (Model), "the selector owns input");
      Assert
        (not Files.Model.Other_Input_Owning_Overlay_Is_Open (Model, Except => Files.UI_Types.Root_Selector_Overlay),
         "the selector's own clicks are not blocked by itself");
      Assert
        (Files.Model.Other_Input_Owning_Overlay_Is_Open (Model, Except => Files.UI_Types.Context_Menu_Overlay),
         "the selector blocks a context menu");
      Assert (Files.Model.Character_Input_Is_Contained (Model), "the selector has no text field of its own");

      Files.Model.Command_Palette.Open (Model);
      Assert
        (Files.Model.Other_Input_Owning_Overlay_Is_Open (Model, Except => Files.UI_Types.Root_Selector_Overlay),
         "the palette over the selector blocks the selector's clicks");
      Assert
        (not Files.Model.Character_Input_Is_Contained (Model),
         "the palette's query field owns text input over the selector");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      if Files.Model.Command_Palette.Is_Open (Model) then
         Assert
           (Files.Model.Character_Input_Is_Contained (Model),
            "an unfocused palette on top contains typed characters");
      end if;
   end Test_Overlay_Queries;
