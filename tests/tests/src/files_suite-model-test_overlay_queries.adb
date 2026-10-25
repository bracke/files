separate (Files_Suite.Model)
   --  Every "is an overlay open" question reads Files.Model's one list of
   --  input-owning overlays: the overlay's own click handler excludes itself,
   --  and the root selector stops owning text input once the palette covers it.
   procedure Test_Overlay_Queries (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Roots : Files.Types.String_Vectors.Vector;
   begin
      Assert (not Files.Model.Input_Owning_Overlay_Is_Open (Model), "no overlay is open at first");
      Assert (not Files.Model.Non_Text_Overlay_Owns_Input (Model), "nothing owns native input at first");
      for Overlay in Files.Model.Input_Overlay loop
         Assert (not Files.Model.Overlay_Is_Open (Model, Overlay), "no single overlay is open at first");
      end loop;

      Roots.Append (Ada.Strings.Unbounded.To_Unbounded_String (Files_Suite.Support.Root));
      Files.Model.Open_Root_Selector (Model, Roots);
      Assert (Files.Model.Overlay_Is_Open (Model, Files.Model.Root_Selector_Overlay), "the selector is open");
      Assert (Files.Model.Input_Owning_Overlay_Is_Open (Model), "the selector owns input");
      Assert
        (not Files.Model.Other_Input_Owning_Overlay_Is_Open (Model, Except => Files.Model.Root_Selector_Overlay),
         "the selector's own clicks are not blocked by itself");
      Assert
        (Files.Model.Other_Input_Owning_Overlay_Is_Open (Model, Except => Files.Model.Context_Menu_Overlay),
         "the selector blocks a context menu");
      Assert (Files.Model.Non_Text_Overlay_Owns_Input (Model), "the selector has no text field of its own");

      Files.Model.Open_Command_Palette (Model);
      Assert
        (Files.Model.Other_Input_Owning_Overlay_Is_Open (Model, Except => Files.Model.Root_Selector_Overlay),
         "the palette over the selector blocks the selector's clicks");
      Assert
        (not Files.Model.Non_Text_Overlay_Owns_Input (Model),
         "the palette's query field owns text input over the selector");
   end Test_Overlay_Queries;
