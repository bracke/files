separate (Files_Suite.Rendering)
   procedure Test_A11ykit_Tree_Mapping (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : View_Snapshot := Sample_Snapshot (4, Files.Types.Small_Icons);
      Frame    : Frame_Commands;
      Tree     : A11ykit.Tree.Accessibility_Tree;
      Profile  : constant Files.Rendering.Accessibility_Integration_Profile :=
        Files.Accessibility.Integration_Profile;
      Roots    : Natural := 0;
      Focused  : Natural := 0;
   begin
      for Index in 1 .. 2 loop
         declare
            Item : Item_Snapshot := Snapshot.Items.Element (Index);
         begin
            Item.Selected := True;
            Snapshot.Items.Replace_Element (Index, Item);
         end;
      end loop;
      Snapshot.Selected_Count := 2;
      Snapshot.Primary_Selected_Visible_Index := 2;
      Frame := Build_Frame_Commands
        (Snapshot, Width => 1200, Height => 800, Line_Height => 20);
      Tree := Files.Accessibility.To_A11ykit_Tree (Frame);

      Assert
        (not Tree.Nodes.Is_Empty,
         "the frame's accessibility nodes map to a non-empty a11ykit tree");
      for Index in Tree.Nodes.First_Index .. Tree.Nodes.Last_Index loop
         --  A well-formed tree: every parent index is 0 (a root) or points at a
         --  real node in the tree.
         Assert
           (Tree.Nodes (Index).Parent <= Natural (Tree.Nodes.Length),
            "every node's parent index is within the tree");
         if Tree.Nodes (Index).Parent = 0 then
            Roots := Roots + 1;
         end if;
         if Tree.Nodes (Index).Node_State.Focused then
            Focused := Focused + 1;
         end if;
      end loop;
      Assert (Roots >= 1, "the mapped tree has at least one root node");
      Files_Suite.Support.Assert_Equal (Focused, 1, "multi-selection exports exactly one primary keyboard-focus node");
      Assert
        (A11ykit.Compatibility.Validate_Tree (Tree).Status =
           A11y.Results.Success,
         "the mapped tree satisfies the provider contract");

      Assert
        (Profile.Native_API_Binding_Status =
           (if A11y.Platforms.Current = A11y.Platforms.Unsupported
            then Files.File_System.Native_API_Binding_Missing
            else Files.File_System.Native_API_Binding_Available),
         "the integration profile reports whether this target has a native provider binding");

      --  The provider needs the first tree before it can register its native
      --  application root. Publication must therefore run even while Available
      --  is initially False; hosts without a live service use the validating
      --  fallback and still report a successful semantic publication.
      Files.Accessibility.Start;
      Files.Accessibility.Start;
      Files.Accessibility.Publish (Files.Accessibility.New_Window_Key, Frame);
      Assert
        (A11ykit.Provider.Last_Publish_Status = A11y.Results.Success,
         "the frame reaches the native provider or its validating fallback: "
         & A11y.Results.Status_Code'Image
             (A11ykit.Provider.Last_Publish_Status));
      Assert
        (A11ykit.Provider.Last_Published_Event_Count > 0,
         "accessibility publication delivers semantic events");
      Assert
        (A11ykit.Provider.Last_Publish_Backend_Name'Length > 0,
         "accessibility publication records the backend that consumed the frame");
      Files.Accessibility.Stop;
      Files.Accessibility.Stop;
      Assert
        (not Files.Accessibility.To_A11ykit_Tree (Frame).Nodes.Is_Empty,
         "the frame still maps after the provider lifetime has been started and stopped");
   end Test_A11ykit_Tree_Mapping;
