namespace EPocalipse.Json.Viewer
{
    partial class JsonViewer
    {
        /// <summary>
        /// Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Component Designer generated code

        /// <summary>
        /// Required method for Designer support - do not modify 
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            this.components = new System.ComponentModel.Container();
            System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(JsonViewer));
            this.spcViewer = new System.Windows.Forms.SplitContainer();
            this.spcViewer2 = new System.Windows.Forms.SplitContainer();
            this.scrollTarget = new System.Windows.Forms.Label();
            this.tvJson = new System.Windows.Forms.TreeView();
            this.mnuTree = new System.Windows.Forms.ContextMenuStrip(this.components);
            this.mnuFind = new System.Windows.Forms.ToolStripMenuItem();
            this.mnuExpandAll = new System.Windows.Forms.ToolStripMenuItem();
            this.toolStripMenuItem1 = new System.Windows.Forms.ToolStripSeparator();
            this.mnuCopy = new System.Windows.Forms.ToolStripMenuItem();
            this.mnuCopyValue = new System.Windows.Forms.ToolStripMenuItem();
            this.imgList = new System.Windows.Forms.ImageList(this.components);
            this.pnlFind = new System.Windows.Forms.Panel();
            this.btnCloseFind = new System.Windows.Forms.Button();
            this.txtFind = new System.Windows.Forms.TextBox();
            this.lblFind = new System.Windows.Forms.Label();
            this.splitContainer1 = new System.Windows.Forms.SplitContainer();
            this.btnJumpToNode = new System.Windows.Forms.Button();
            this.lblParseSrcFile = new System.Windows.Forms.Label();
            this.rtxtParsedSrc = new System.Windows.Forms.RichTextBox();
            this.tableLayoutPanel1 = new System.Windows.Forms.TableLayoutPanel();
            this.panel1 = new System.Windows.Forms.Panel();
            this.label2 = new System.Windows.Forms.Label();
            this.ckParseTreeMode = new System.Windows.Forms.CheckBox();
            this.label1 = new System.Windows.Forms.Label();
            this.txtLabelName = new System.Windows.Forms.TextBox();
            this.ckObjectsOnly = new System.Windows.Forms.CheckBox();
            this.cbVisualizers = new System.Windows.Forms.ComboBox();
            this.pnlVisualizer = new System.Windows.Forms.Panel();
            this.mnuVisualizerPnl = new System.Windows.Forms.ContextMenuStrip(this.components);
            this.mnuShowOnRight = new System.Windows.Forms.ToolStripMenuItem();
            this.mnuShowOnBottom = new System.Windows.Forms.ToolStripMenuItem();
            this.pnlOptions = new System.Windows.Forms.Panel();
            this.tabControl = new System.Windows.Forms.TabControl();
            this.pageTreeView = new System.Windows.Forms.TabPage();
            this.pageTextView = new System.Windows.Forms.TabPage();
            this.txtJson = new System.Windows.Forms.TextBox();
            this.toolStrip1 = new System.Windows.Forms.ToolStrip();
            this.btnPaste = new System.Windows.Forms.ToolStripButton();
            this.btnCopy = new System.Windows.Forms.ToolStripButton();
            this.toolStripSeparator1 = new System.Windows.Forms.ToolStripSeparator();
            this.btnFormat = new System.Windows.Forms.ToolStripButton();
            this.btnStrip = new System.Windows.Forms.ToolStripSplitButton();
            this.btnStripToCurly = new System.Windows.Forms.ToolStripMenuItem();
            this.btnStripToSqr = new System.Windows.Forms.ToolStripMenuItem();
            this.toolStripSplitButton1 = new System.Windows.Forms.ToolStripSplitButton();
            this.removenToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.removeSpecialCharsToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.lblError = new System.Windows.Forms.LinkLabel();
            this.spcViewer.Panel1.SuspendLayout();
            this.spcViewer.Panel2.SuspendLayout();
            this.spcViewer.SuspendLayout();
            this.spcViewer2.Panel1.SuspendLayout();
            this.spcViewer2.Panel2.SuspendLayout();
            this.spcViewer2.SuspendLayout();
            this.mnuTree.SuspendLayout();
            this.pnlFind.SuspendLayout();
            this.splitContainer1.Panel1.SuspendLayout();
            this.splitContainer1.Panel2.SuspendLayout();
            this.splitContainer1.SuspendLayout();
            this.tableLayoutPanel1.SuspendLayout();
            this.panel1.SuspendLayout();
            this.mnuVisualizerPnl.SuspendLayout();
            this.tabControl.SuspendLayout();
            this.pageTreeView.SuspendLayout();
            this.pageTextView.SuspendLayout();
            this.toolStrip1.SuspendLayout();
            this.SuspendLayout();
            // 
            // spcViewer
            // 
            this.spcViewer.Dock = System.Windows.Forms.DockStyle.Fill;
            this.spcViewer.Location = new System.Drawing.Point(3, 3);
            this.spcViewer.Name = "spcViewer";
            // 
            // spcViewer.Panel1
            // 
            this.spcViewer.Panel1.Controls.Add(this.spcViewer2);
            // 
            // spcViewer.Panel2
            // 
            this.spcViewer.Panel2.Controls.Add(this.tableLayoutPanel1);
            this.spcViewer.Panel2.Controls.Add(this.pnlOptions);
            this.spcViewer.Size = new System.Drawing.Size(778, 572);
            this.spcViewer.SplitterDistance = 600;
            this.spcViewer.TabIndex = 5;
            // 
            // spcViewer2
            // 
            this.spcViewer2.Dock = System.Windows.Forms.DockStyle.Fill;
            this.spcViewer2.Location = new System.Drawing.Point(0, 0);
            this.spcViewer2.Name = "spcViewer2";
            // 
            // spcViewer2.Panel1
            // 
            this.spcViewer2.Panel1.Controls.Add(this.scrollTarget);
            this.spcViewer2.Panel1.Controls.Add(this.tvJson);
            this.spcViewer2.Panel1.Controls.Add(this.pnlFind);
            // 
            // spcViewer2.Panel2
            // 
            this.spcViewer2.Panel2.Controls.Add(this.splitContainer1);
            this.spcViewer2.Size = new System.Drawing.Size(600, 572);
            this.spcViewer2.SplitterDistance = 317;
            this.spcViewer2.TabIndex = 7;
            // 
            // scrollTarget
            // 
            this.scrollTarget.AutoSize = true;
            this.scrollTarget.Location = new System.Drawing.Point(47, 103);
            this.scrollTarget.Name = "scrollTarget";
            this.scrollTarget.Size = new System.Drawing.Size(75, 13);
            this.scrollTarget.TabIndex = 7;
            this.scrollTarget.Text = "{Scroll Target}";
            this.scrollTarget.Visible = false;
            // 
            // tvJson
            // 
            this.tvJson.ContextMenuStrip = this.mnuTree;
            this.tvJson.Dock = System.Windows.Forms.DockStyle.Fill;
            this.tvJson.HideSelection = false;
            this.tvJson.ImageIndex = 0;
            this.tvJson.ImageList = this.imgList;
            this.tvJson.Location = new System.Drawing.Point(0, 0);
            this.tvJson.Name = "tvJson";
            this.tvJson.SelectedImageIndex = 0;
            this.tvJson.Size = new System.Drawing.Size(317, 540);
            this.tvJson.TabIndex = 3;
            this.tvJson.BeforeExpand += new System.Windows.Forms.TreeViewCancelEventHandler(this.tvJson_BeforeExpand);
            this.tvJson.AfterSelect += new System.Windows.Forms.TreeViewEventHandler(this.tvJson_AfterSelect);
            this.tvJson.MouseDown += new System.Windows.Forms.MouseEventHandler(this.tvJson_MouseDown);
            this.tvJson.KeyDown += new System.Windows.Forms.KeyEventHandler(this.JsonViewer_KeyDown);
            // 
            // mnuTree
            // 
            this.mnuTree.Items.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.mnuFind,
            this.mnuExpandAll,
            this.toolStripMenuItem1,
            this.mnuCopy,
            this.mnuCopyValue});
            this.mnuTree.Name = "mnuTree";
            this.mnuTree.Size = new System.Drawing.Size(141, 98);
            this.mnuTree.Opening += new System.ComponentModel.CancelEventHandler(this.mnuTree_Opening);
            // 
            // mnuFind
            // 
            this.mnuFind.Name = "mnuFind";
            this.mnuFind.Size = new System.Drawing.Size(140, 22);
            this.mnuFind.Text = "&Find";
            this.mnuFind.Click += new System.EventHandler(this.findToolStripMenuItem_Click);
            // 
            // mnuExpandAll
            // 
            this.mnuExpandAll.Name = "mnuExpandAll";
            this.mnuExpandAll.Size = new System.Drawing.Size(140, 22);
            this.mnuExpandAll.Text = "Expand &All";
            this.mnuExpandAll.Click += new System.EventHandler(this.expandallToolStripMenuItem_Click);
            // 
            // toolStripMenuItem1
            // 
            this.toolStripMenuItem1.Name = "toolStripMenuItem1";
            this.toolStripMenuItem1.Size = new System.Drawing.Size(137, 6);
            // 
            // mnuCopy
            // 
            this.mnuCopy.Name = "mnuCopy";
            this.mnuCopy.Size = new System.Drawing.Size(140, 22);
            this.mnuCopy.Text = "&Copy";
            this.mnuCopy.Click += new System.EventHandler(this.mnuCopy_Click);
            // 
            // mnuCopyValue
            // 
            this.mnuCopyValue.Name = "mnuCopyValue";
            this.mnuCopyValue.Size = new System.Drawing.Size(140, 22);
            this.mnuCopyValue.Text = "Copy &Value";
            this.mnuCopyValue.Click += new System.EventHandler(this.mnuCopyValue_Click);
            // 
            // imgList
            // 
            this.imgList.ImageStream = ((System.Windows.Forms.ImageListStreamer)(resources.GetObject("imgList.ImageStream")));
            this.imgList.TransparentColor = System.Drawing.Color.White;
            this.imgList.Images.SetKeyName(0, "obj.bmp");
            this.imgList.Images.SetKeyName(1, "array.bmp");
            this.imgList.Images.SetKeyName(2, "prop.bmp");
            // 
            // pnlFind
            // 
            this.pnlFind.Controls.Add(this.btnCloseFind);
            this.pnlFind.Controls.Add(this.txtFind);
            this.pnlFind.Controls.Add(this.lblFind);
            this.pnlFind.Dock = System.Windows.Forms.DockStyle.Bottom;
            this.pnlFind.Location = new System.Drawing.Point(0, 540);
            this.pnlFind.Name = "pnlFind";
            this.pnlFind.Size = new System.Drawing.Size(317, 32);
            this.pnlFind.TabIndex = 6;
            this.pnlFind.Visible = false;
            // 
            // btnCloseFind
            // 
            this.btnCloseFind.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Right)));
            this.btnCloseFind.BackColor = System.Drawing.Color.Transparent;
            this.btnCloseFind.BackgroundImage = ((System.Drawing.Image)(resources.GetObject("btnCloseFind.BackgroundImage")));
            this.btnCloseFind.BackgroundImageLayout = System.Windows.Forms.ImageLayout.Center;
            this.btnCloseFind.FlatAppearance.BorderSize = 0;
            this.btnCloseFind.FlatStyle = System.Windows.Forms.FlatStyle.Flat;
            this.btnCloseFind.Location = new System.Drawing.Point(290, 7);
            this.btnCloseFind.Name = "btnCloseFind";
            this.btnCloseFind.Size = new System.Drawing.Size(16, 16);
            this.btnCloseFind.TabIndex = 2;
            this.btnCloseFind.UseVisualStyleBackColor = false;
            this.btnCloseFind.Click += new System.EventHandler(this.btnCloseFind_Click);
            // 
            // txtFind
            // 
            this.txtFind.Anchor = ((System.Windows.Forms.AnchorStyles)(((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Left) 
            | System.Windows.Forms.AnchorStyles.Right)));
            this.txtFind.BorderStyle = System.Windows.Forms.BorderStyle.FixedSingle;
            this.txtFind.Location = new System.Drawing.Point(32, 6);
            this.txtFind.Name = "txtFind";
            this.txtFind.Size = new System.Drawing.Size(267, 20);
            this.txtFind.TabIndex = 1;
            this.txtFind.TextChanged += new System.EventHandler(this.txtFind_TextChanged);
            this.txtFind.KeyDown += new System.Windows.Forms.KeyEventHandler(this.txtFind_KeyDown);
            // 
            // lblFind
            // 
            this.lblFind.AutoSize = true;
            this.lblFind.Location = new System.Drawing.Point(3, 9);
            this.lblFind.Name = "lblFind";
            this.lblFind.Size = new System.Drawing.Size(27, 13);
            this.lblFind.TabIndex = 0;
            this.lblFind.Text = "&Find";
            // 
            // splitContainer1
            // 
            this.splitContainer1.Dock = System.Windows.Forms.DockStyle.Fill;
            this.splitContainer1.Location = new System.Drawing.Point(0, 0);
            this.splitContainer1.Margin = new System.Windows.Forms.Padding(0);
            this.splitContainer1.Name = "splitContainer1";
            this.splitContainer1.Orientation = System.Windows.Forms.Orientation.Horizontal;
            // 
            // splitContainer1.Panel1
            // 
            this.splitContainer1.Panel1.Controls.Add(this.btnJumpToNode);
            this.splitContainer1.Panel1.Controls.Add(this.lblParseSrcFile);
            this.splitContainer1.Panel1MinSize = 30;
            // 
            // splitContainer1.Panel2
            // 
            this.splitContainer1.Panel2.Controls.Add(this.rtxtParsedSrc);
            this.splitContainer1.Size = new System.Drawing.Size(279, 572);
            this.splitContainer1.SplitterDistance = 30;
            this.splitContainer1.TabIndex = 6;
            // 
            // btnJumpToNode
            // 
            this.btnJumpToNode.Dock = System.Windows.Forms.DockStyle.Right;
            this.btnJumpToNode.Enabled = false;
            this.btnJumpToNode.Location = new System.Drawing.Point(193, 0);
            this.btnJumpToNode.Name = "btnJumpToNode";
            this.btnJumpToNode.Size = new System.Drawing.Size(86, 30);
            this.btnJumpToNode.TabIndex = 6;
            this.btnJumpToNode.Text = "Jump To Node";
            this.btnJumpToNode.UseVisualStyleBackColor = true;
            this.btnJumpToNode.Click += new System.EventHandler(this.btnJumpToNode_Click);
            // 
            // lblParseSrcFile
            // 
            this.lblParseSrcFile.AutoSize = true;
            this.lblParseSrcFile.Location = new System.Drawing.Point(0, 12);
            this.lblParseSrcFile.Name = "lblParseSrcFile";
            this.lblParseSrcFile.Size = new System.Drawing.Size(46, 13);
            this.lblParseSrcFile.TabIndex = 5;
            this.lblParseSrcFile.Text = "filename";
            // 
            // rtxtParsedSrc
            // 
            this.rtxtParsedSrc.Dock = System.Windows.Forms.DockStyle.Fill;
            this.rtxtParsedSrc.Font = new System.Drawing.Font("Courier New", 9.75F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.rtxtParsedSrc.HideSelection = false;
            this.rtxtParsedSrc.Location = new System.Drawing.Point(0, 0);
            this.rtxtParsedSrc.Name = "rtxtParsedSrc";
            this.rtxtParsedSrc.ReadOnly = true;
            this.rtxtParsedSrc.Size = new System.Drawing.Size(279, 538);
            this.rtxtParsedSrc.TabIndex = 1;
            this.rtxtParsedSrc.Text = "";
            this.rtxtParsedSrc.WordWrap = false;
            this.rtxtParsedSrc.SelectionChanged += new System.EventHandler(this.rtxtParsedSrc_SelectionChanged);
            this.rtxtParsedSrc.LostFocus += new System.EventHandler(this.rtxtParsedSrc_LostFocus);
            this.rtxtParsedSrc.GotFocus += new System.EventHandler(this.rtxtParsedSrc_GotFocus);
            // 
            // tableLayoutPanel1
            // 
            this.tableLayoutPanel1.ColumnCount = 1;
            this.tableLayoutPanel1.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 100F));
            this.tableLayoutPanel1.Controls.Add(this.panel1, 0, 0);
            this.tableLayoutPanel1.Controls.Add(this.cbVisualizers, 0, 1);
            this.tableLayoutPanel1.Controls.Add(this.pnlVisualizer, 0, 2);
            this.tableLayoutPanel1.Dock = System.Windows.Forms.DockStyle.Fill;
            this.tableLayoutPanel1.Location = new System.Drawing.Point(0, 0);
            this.tableLayoutPanel1.Name = "tableLayoutPanel1";
            this.tableLayoutPanel1.RowCount = 3;
            this.tableLayoutPanel1.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 100F));
            this.tableLayoutPanel1.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 23F));
            this.tableLayoutPanel1.RowStyles.Add(new System.Windows.Forms.RowStyle());
            this.tableLayoutPanel1.Size = new System.Drawing.Size(174, 572);
            this.tableLayoutPanel1.TabIndex = 10;
            // 
            // panel1
            // 
            this.panel1.Controls.Add(this.label2);
            this.panel1.Controls.Add(this.ckParseTreeMode);
            this.panel1.Controls.Add(this.label1);
            this.panel1.Controls.Add(this.txtLabelName);
            this.panel1.Controls.Add(this.ckObjectsOnly);
            this.panel1.Dock = System.Windows.Forms.DockStyle.Fill;
            this.panel1.Location = new System.Drawing.Point(0, 0);
            this.panel1.Margin = new System.Windows.Forms.Padding(0);
            this.panel1.Name = "panel1";
            this.panel1.Size = new System.Drawing.Size(174, 100);
            this.panel1.TabIndex = 9;
            // 
            // label2
            // 
            this.label2.AutoSize = true;
            this.label2.Location = new System.Drawing.Point(0, 62);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(152, 13);
            this.label2.TabIndex = 12;
            this.label2.Text = "(An invalid field disables labels)";
            // 
            // ckParseTreeMode
            // 
            this.ckParseTreeMode.AutoSize = true;
            this.ckParseTreeMode.Location = new System.Drawing.Point(4, 3);
            this.ckParseTreeMode.Name = "ckParseTreeMode";
            this.ckParseTreeMode.Size = new System.Drawing.Size(108, 17);
            this.ckParseTreeMode.TabIndex = 11;
            this.ckParseTreeMode.Text = "Parse Tree Mode";
            this.ckParseTreeMode.UseVisualStyleBackColor = true;
            this.ckParseTreeMode.CheckedChanged += new System.EventHandler(this.ckParseTreeMode_CheckedChanged);
            // 
            // label1
            // 
            this.label1.AutoSize = true;
            this.label1.Location = new System.Drawing.Point(1, 48);
            this.label1.Name = "label1";
            this.label1.Size = new System.Drawing.Size(159, 13);
            this.label1.TabIndex = 10;
            this.label1.Text = "Name of Field to use as a Label:";
            // 
            // txtLabelName
            // 
            this.txtLabelName.Dock = System.Windows.Forms.DockStyle.Bottom;
            this.txtLabelName.Location = new System.Drawing.Point(0, 80);
            this.txtLabelName.Name = "txtLabelName";
            this.txtLabelName.Size = new System.Drawing.Size(174, 20);
            this.txtLabelName.TabIndex = 9;
            this.txtLabelName.TextChanged += new System.EventHandler(this.txtLabelName_TextChanged);
            // 
            // ckObjectsOnly
            // 
            this.ckObjectsOnly.AutoSize = true;
            this.ckObjectsOnly.Location = new System.Drawing.Point(4, 23);
            this.ckObjectsOnly.Name = "ckObjectsOnly";
            this.ckObjectsOnly.Size = new System.Drawing.Size(112, 17);
            this.ckObjectsOnly.TabIndex = 8;
            this.ckObjectsOnly.Text = "View Objects Only";
            this.ckObjectsOnly.UseVisualStyleBackColor = true;
            this.ckObjectsOnly.CheckedChanged += new System.EventHandler(this.ckObjectsOnly_CheckedChanged);
            // 
            // cbVisualizers
            // 
            this.cbVisualizers.Dock = System.Windows.Forms.DockStyle.Top;
            this.cbVisualizers.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.cbVisualizers.FlatStyle = System.Windows.Forms.FlatStyle.System;
            this.cbVisualizers.FormattingEnabled = true;
            this.cbVisualizers.Location = new System.Drawing.Point(3, 103);
            this.cbVisualizers.Name = "cbVisualizers";
            this.cbVisualizers.Size = new System.Drawing.Size(168, 21);
            this.cbVisualizers.Sorted = true;
            this.cbVisualizers.TabIndex = 7;
            this.cbVisualizers.SelectedIndexChanged += new System.EventHandler(this.cbVisualizers_SelectedIndexChanged);
            this.cbVisualizers.Format += new System.Windows.Forms.ListControlConvertEventHandler(this.cbVisualizers_Format);
            // 
            // pnlVisualizer
            // 
            this.pnlVisualizer.ContextMenuStrip = this.mnuVisualizerPnl;
            this.pnlVisualizer.Dock = System.Windows.Forms.DockStyle.Fill;
            this.pnlVisualizer.Location = new System.Drawing.Point(3, 126);
            this.pnlVisualizer.Name = "pnlVisualizer";
            this.pnlVisualizer.Size = new System.Drawing.Size(168, 497);
            this.pnlVisualizer.TabIndex = 6;
            // 
            // mnuVisualizerPnl
            // 
            this.mnuVisualizerPnl.Items.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.mnuShowOnRight,
            this.mnuShowOnBottom});
            this.mnuVisualizerPnl.Name = "mnuVisualizerPnl";
            this.mnuVisualizerPnl.Size = new System.Drawing.Size(117, 48);
            // 
            // mnuShowOnRight
            // 
            this.mnuShowOnRight.Checked = true;
            this.mnuShowOnRight.CheckOnClick = true;
            this.mnuShowOnRight.CheckState = System.Windows.Forms.CheckState.Checked;
            this.mnuShowOnRight.Name = "mnuShowOnRight";
            this.mnuShowOnRight.Size = new System.Drawing.Size(116, 22);
            this.mnuShowOnRight.Text = "&Right";
            this.mnuShowOnRight.Click += new System.EventHandler(this.rightToolStripMenuItem_Click);
            // 
            // mnuShowOnBottom
            // 
            this.mnuShowOnBottom.CheckOnClick = true;
            this.mnuShowOnBottom.Name = "mnuShowOnBottom";
            this.mnuShowOnBottom.Size = new System.Drawing.Size(116, 22);
            this.mnuShowOnBottom.Text = "&Bottom";
            this.mnuShowOnBottom.Click += new System.EventHandler(this.rightToolStripMenuItem_Click);
            // 
            // pnlOptions
            // 
            this.pnlOptions.AutoSize = true;
            this.pnlOptions.Dock = System.Windows.Forms.DockStyle.Top;
            this.pnlOptions.Location = new System.Drawing.Point(0, 0);
            this.pnlOptions.Name = "pnlOptions";
            this.pnlOptions.Size = new System.Drawing.Size(174, 0);
            this.pnlOptions.TabIndex = 9;
            // 
            // tabControl
            // 
            this.tabControl.Controls.Add(this.pageTreeView);
            this.tabControl.Controls.Add(this.pageTextView);
            this.tabControl.Dock = System.Windows.Forms.DockStyle.Fill;
            this.tabControl.Location = new System.Drawing.Point(0, 0);
            this.tabControl.Name = "tabControl";
            this.tabControl.SelectedIndex = 0;
            this.tabControl.Size = new System.Drawing.Size(792, 604);
            this.tabControl.TabIndex = 6;
            // 
            // pageTreeView
            // 
            this.pageTreeView.Controls.Add(this.spcViewer);
            this.pageTreeView.Location = new System.Drawing.Point(4, 22);
            this.pageTreeView.Name = "pageTreeView";
            this.pageTreeView.Padding = new System.Windows.Forms.Padding(3);
            this.pageTreeView.Size = new System.Drawing.Size(784, 578);
            this.pageTreeView.TabIndex = 0;
            this.pageTreeView.Text = "Viewer";
            this.pageTreeView.UseVisualStyleBackColor = true;
            // 
            // pageTextView
            // 
            this.pageTextView.Controls.Add(this.txtJson);
            this.pageTextView.Controls.Add(this.toolStrip1);
            this.pageTextView.Controls.Add(this.lblError);
            this.pageTextView.Location = new System.Drawing.Point(4, 22);
            this.pageTextView.Name = "pageTextView";
            this.pageTextView.Padding = new System.Windows.Forms.Padding(3);
            this.pageTextView.Size = new System.Drawing.Size(784, 578);
            this.pageTextView.TabIndex = 1;
            this.pageTextView.Text = "Text";
            this.pageTextView.UseVisualStyleBackColor = true;
            // 
            // txtJson
            // 
            this.txtJson.AcceptsReturn = true;
            this.txtJson.AcceptsTab = true;
            this.txtJson.BackColor = System.Drawing.SystemColors.Window;
            this.txtJson.Dock = System.Windows.Forms.DockStyle.Fill;
            this.txtJson.HideSelection = false;
            this.txtJson.Location = new System.Drawing.Point(3, 28);
            this.txtJson.MaxLength = 0;
            this.txtJson.Multiline = true;
            this.txtJson.Name = "txtJson";
            this.txtJson.ScrollBars = System.Windows.Forms.ScrollBars.Both;
            this.txtJson.Size = new System.Drawing.Size(778, 523);
            this.txtJson.TabIndex = 4;
            this.txtJson.TextChanged += new System.EventHandler(this.txtJson_TextChanged);
            // 
            // toolStrip1
            // 
            this.toolStrip1.BackColor = System.Drawing.SystemColors.Control;
            this.toolStrip1.Items.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.btnPaste,
            this.btnCopy,
            this.toolStripSeparator1,
            this.btnFormat,
            this.btnStrip,
            this.toolStripSplitButton1});
            this.toolStrip1.Location = new System.Drawing.Point(3, 3);
            this.toolStrip1.Name = "toolStrip1";
            this.toolStrip1.RenderMode = System.Windows.Forms.ToolStripRenderMode.System;
            this.toolStrip1.Size = new System.Drawing.Size(778, 25);
            this.toolStrip1.TabIndex = 6;
            this.toolStrip1.Text = "toolStrip1";
            // 
            // btnPaste
            // 
            this.btnPaste.DisplayStyle = System.Windows.Forms.ToolStripItemDisplayStyle.Text;
            this.btnPaste.Image = ((System.Drawing.Image)(resources.GetObject("btnPaste.Image")));
            this.btnPaste.ImageTransparentColor = System.Drawing.Color.Magenta;
            this.btnPaste.Name = "btnPaste";
            this.btnPaste.Size = new System.Drawing.Size(43, 22);
            this.btnPaste.Text = "&Paste";
            this.btnPaste.Click += new System.EventHandler(this.btnPaste_Click);
            // 
            // btnCopy
            // 
            this.btnCopy.DisplayStyle = System.Windows.Forms.ToolStripItemDisplayStyle.Text;
            this.btnCopy.Image = ((System.Drawing.Image)(resources.GetObject("btnCopy.Image")));
            this.btnCopy.ImageTransparentColor = System.Drawing.Color.Magenta;
            this.btnCopy.Name = "btnCopy";
            this.btnCopy.Size = new System.Drawing.Size(40, 22);
            this.btnCopy.Text = "&Copy";
            this.btnCopy.Click += new System.EventHandler(this.btnCopy_Click);
            // 
            // toolStripSeparator1
            // 
            this.toolStripSeparator1.Name = "toolStripSeparator1";
            this.toolStripSeparator1.Size = new System.Drawing.Size(6, 25);
            // 
            // btnFormat
            // 
            this.btnFormat.DisplayStyle = System.Windows.Forms.ToolStripItemDisplayStyle.Text;
            this.btnFormat.Image = ((System.Drawing.Image)(resources.GetObject("btnFormat.Image")));
            this.btnFormat.ImageTransparentColor = System.Drawing.Color.Magenta;
            this.btnFormat.Name = "btnFormat";
            this.btnFormat.Size = new System.Drawing.Size(53, 22);
            this.btnFormat.Text = "&Format";
            this.btnFormat.Click += new System.EventHandler(this.btnFormat_Click);
            // 
            // btnStrip
            // 
            this.btnStrip.DisplayStyle = System.Windows.Forms.ToolStripItemDisplayStyle.Text;
            this.btnStrip.DropDownItems.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.btnStripToCurly,
            this.btnStripToSqr});
            this.btnStrip.Image = ((System.Drawing.Image)(resources.GetObject("btnStrip.Image")));
            this.btnStrip.ImageTransparentColor = System.Drawing.Color.Magenta;
            this.btnStrip.Name = "btnStrip";
            this.btnStrip.Size = new System.Drawing.Size(82, 22);
            this.btnStrip.Text = "Strip to {}";
            this.btnStrip.ButtonClick += new System.EventHandler(this.btnStripToCurly_Click);
            // 
            // btnStripToCurly
            // 
            this.btnStripToCurly.DisplayStyle = System.Windows.Forms.ToolStripItemDisplayStyle.Text;
            this.btnStripToCurly.Name = "btnStripToCurly";
            this.btnStripToCurly.Size = new System.Drawing.Size(134, 22);
            this.btnStripToCurly.Text = "Strip to {}";
            this.btnStripToCurly.Click += new System.EventHandler(this.btnStripToCurly_Click);
            // 
            // btnStripToSqr
            // 
            this.btnStripToSqr.DisplayStyle = System.Windows.Forms.ToolStripItemDisplayStyle.Text;
            this.btnStripToSqr.Name = "btnStripToSqr";
            this.btnStripToSqr.Size = new System.Drawing.Size(134, 22);
            this.btnStripToSqr.Text = "Strip to []";
            this.btnStripToSqr.Click += new System.EventHandler(this.btnStripToSqr_Click);
            // 
            // toolStripSplitButton1
            // 
            this.toolStripSplitButton1.DisplayStyle = System.Windows.Forms.ToolStripItemDisplayStyle.Text;
            this.toolStripSplitButton1.DropDownItems.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.removenToolStripMenuItem,
            this.removeSpecialCharsToolStripMenuItem});
            this.toolStripSplitButton1.Image = ((System.Drawing.Image)(resources.GetObject("toolStripSplitButton1.Image")));
            this.toolStripSplitButton1.ImageTransparentColor = System.Drawing.Color.Magenta;
            this.toolStripSplitButton1.Name = "toolStripSplitButton1";
            this.toolStripSplitButton1.Size = new System.Drawing.Size(154, 22);
            this.toolStripSplitButton1.Text = "Remove new lines (\\n)";
            this.toolStripSplitButton1.ButtonClick += new System.EventHandler(this.removeNewLineMenuItem_Click);
            // 
            // removenToolStripMenuItem
            // 
            this.removenToolStripMenuItem.DisplayStyle = System.Windows.Forms.ToolStripItemDisplayStyle.Text;
            this.removenToolStripMenuItem.Name = "removenToolStripMenuItem";
            this.removenToolStripMenuItem.Size = new System.Drawing.Size(219, 22);
            this.removenToolStripMenuItem.Text = "Remove new lines (\\n)";
            this.removenToolStripMenuItem.Click += new System.EventHandler(this.removeNewLineMenuItem_Click);
            // 
            // removeSpecialCharsToolStripMenuItem
            // 
            this.removeSpecialCharsToolStripMenuItem.DisplayStyle = System.Windows.Forms.ToolStripItemDisplayStyle.Text;
            this.removeSpecialCharsToolStripMenuItem.Name = "removeSpecialCharsToolStripMenuItem";
            this.removeSpecialCharsToolStripMenuItem.Size = new System.Drawing.Size(219, 22);
            this.removeSpecialCharsToolStripMenuItem.Text = "Remove special chars (\\)";
            this.removeSpecialCharsToolStripMenuItem.Click += new System.EventHandler(this.removeSpecialCharsToolStripMenuItem_Click);
            // 
            // lblError
            // 
            this.lblError.Dock = System.Windows.Forms.DockStyle.Bottom;
            this.lblError.ForeColor = System.Drawing.Color.Red;
            this.lblError.LinkBehavior = System.Windows.Forms.LinkBehavior.AlwaysUnderline;
            this.lblError.LinkColor = System.Drawing.Color.Red;
            this.lblError.Location = new System.Drawing.Point(3, 551);
            this.lblError.Name = "lblError";
            this.lblError.Size = new System.Drawing.Size(778, 24);
            this.lblError.TabIndex = 5;
            this.lblError.TabStop = true;
            this.lblError.Text = "aa";
            this.lblError.VisitedLinkColor = System.Drawing.Color.Red;
            this.lblError.LinkClicked += new System.Windows.Forms.LinkLabelLinkClickedEventHandler(this.lblError_LinkClicked);
            // 
            // JsonViewer
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.Controls.Add(this.tabControl);
            this.Name = "JsonViewer";
            this.Size = new System.Drawing.Size(792, 604);
            this.KeyDown += new System.Windows.Forms.KeyEventHandler(this.JsonViewer_KeyDown);
            this.spcViewer.Panel1.ResumeLayout(false);
            this.spcViewer.Panel2.ResumeLayout(false);
            this.spcViewer.Panel2.PerformLayout();
            this.spcViewer.ResumeLayout(false);
            this.spcViewer2.Panel1.ResumeLayout(false);
            this.spcViewer2.Panel1.PerformLayout();
            this.spcViewer2.Panel2.ResumeLayout(false);
            this.spcViewer2.ResumeLayout(false);
            this.mnuTree.ResumeLayout(false);
            this.pnlFind.ResumeLayout(false);
            this.pnlFind.PerformLayout();
            this.splitContainer1.Panel1.ResumeLayout(false);
            this.splitContainer1.Panel1.PerformLayout();
            this.splitContainer1.Panel2.ResumeLayout(false);
            this.splitContainer1.ResumeLayout(false);
            this.tableLayoutPanel1.ResumeLayout(false);
            this.panel1.ResumeLayout(false);
            this.panel1.PerformLayout();
            this.mnuVisualizerPnl.ResumeLayout(false);
            this.tabControl.ResumeLayout(false);
            this.pageTreeView.ResumeLayout(false);
            this.pageTextView.ResumeLayout(false);
            this.pageTextView.PerformLayout();
            this.toolStrip1.ResumeLayout(false);
            this.toolStrip1.PerformLayout();
            this.ResumeLayout(false);

        }

        #endregion

        private System.Windows.Forms.SplitContainer spcViewer;
        private System.Windows.Forms.ImageList imgList;
        private System.Windows.Forms.TreeView tvJson;
        private System.Windows.Forms.TabControl tabControl;
        private System.Windows.Forms.TabPage pageTreeView;
        private System.Windows.Forms.TabPage pageTextView;
        private System.Windows.Forms.TextBox txtJson;
        private System.Windows.Forms.LinkLabel lblError;
        private System.Windows.Forms.ToolStrip toolStrip1;
        private System.Windows.Forms.ToolStripButton btnFormat;
        private System.Windows.Forms.ToolStripSplitButton btnStrip;
        private System.Windows.Forms.ToolStripMenuItem btnStripToCurly;
        private System.Windows.Forms.ToolStripMenuItem btnStripToSqr;
        private System.Windows.Forms.Panel pnlVisualizer;
        private System.Windows.Forms.Panel pnlFind;
        private System.Windows.Forms.TextBox txtFind;
        private System.Windows.Forms.Label lblFind;
        private System.Windows.Forms.Button btnCloseFind;
        private System.Windows.Forms.ContextMenuStrip mnuTree;
        private System.Windows.Forms.ToolStripMenuItem mnuFind;
        private System.Windows.Forms.ToolStripMenuItem mnuExpandAll;
        private System.Windows.Forms.ContextMenuStrip mnuVisualizerPnl;
        private System.Windows.Forms.ToolStripMenuItem mnuShowOnRight;
        private System.Windows.Forms.ToolStripMenuItem mnuShowOnBottom;
        private System.Windows.Forms.ComboBox cbVisualizers;
        private System.Windows.Forms.ToolStripButton btnPaste;
        private System.Windows.Forms.ToolStripButton btnCopy;
        private System.Windows.Forms.ToolStripSeparator toolStripSeparator1;
        private System.Windows.Forms.ToolStripSeparator toolStripMenuItem1;
        private System.Windows.Forms.ToolStripMenuItem mnuCopy;
        private System.Windows.Forms.ToolStripMenuItem mnuCopyValue;
        private System.Windows.Forms.ToolStripSplitButton toolStripSplitButton1;
        private System.Windows.Forms.ToolStripMenuItem removenToolStripMenuItem;
        private System.Windows.Forms.ToolStripMenuItem removeSpecialCharsToolStripMenuItem;
        private System.Windows.Forms.CheckBox ckObjectsOnly;
        private System.Windows.Forms.Panel pnlOptions;
        private System.Windows.Forms.TableLayoutPanel tableLayoutPanel1;
        private System.Windows.Forms.Panel panel1;
        private System.Windows.Forms.Label label1;
        private System.Windows.Forms.TextBox txtLabelName;
        private System.Windows.Forms.SplitContainer spcViewer2;
        private System.Windows.Forms.CheckBox ckParseTreeMode;
        private System.Windows.Forms.RichTextBox rtxtParsedSrc;
        private System.Windows.Forms.Label lblParseSrcFile;
        private System.Windows.Forms.SplitContainer splitContainer1;
        private System.Windows.Forms.Label label2;
        private System.Windows.Forms.Button btnJumpToNode;
        private System.Windows.Forms.Label scrollTarget;

    }
}
