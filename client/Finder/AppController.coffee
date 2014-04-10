class FinderController extends KDController

  KD.registerAppClass this,
    name         : "Finder"
    background   : yes

  constructor:(options, data)->

    options.appInfo = name : "Finder"

    super options, data

  createFileFromPath:(rest...)-> FSHelper.createFileFromPath rest...

  create: (options = {}) ->
    options.useStorage       ?= yes
    options.addOrphansToRoot ?= no
    options.delegate         ?= this
    @controller = new NFinderController options

    @controller.getView().addSubView @getAppTitleView()
    @controller.getView().addSubView @getUploader()
    @controller.getView().addSubView @getMountVMButton()
    return @controller

  getAppTitleView: ->
    return new KDCustomHTMLView
      cssClass : "app-header"
      partial  : "Ace Editor"

  getMountVMButton: ->
    @uploaderPlaceholder = new KDButtonView
      title    : "Mount other VMs"
      cssClass : "finder-mountvm clean-gray"
      callback : @bound 'showMountVMModal'

  getUploader: ->
    @uploaderPlaceholder = new KDView
      domId       : "finder-dnduploader"
      cssClass    : "hidden"

    @uploaderPlaceholder.addSubView @uploader = new DNDUploader
      hoverDetect : no
      delegate    : this

    {treeController} = @controller
    treeController.on 'dragEnter', @bound "onDrag"
    treeController.on 'dragOver' , @bound "onDrag"

    @uploader
      .on "dragleave", =>
        @uploaderPlaceholder.hide()

      .on "drop", =>
        @uploaderPlaceholder.hide()

      .on 'uploadProgress', ({ file, percent }) ->
        filePath = "[#{file.vmName}]#{file.path}"
        treeController.nodes[filePath]?.showProgressView percent

      .on "uploadComplete", ({ parentPath }) =>
        @controller.expandFolders FSHelper.getPathHierarchy parentPath

      .on "cancel", =>
        @uploader.setPath()
        @uploaderPlaceholder.hide()

    return @uploaderPlaceholder

  onDrag: ->
    return  if @controller.treeController.internalDragging
    @uploaderPlaceholder.show()
    @uploader.unsetClass "hover"

  showMountVMModal: ->
    modal = new KDModalView
      width         : 620
      cssClass      : "modal-with-text mount-vm"
      title         : "Mount VMs"
      overlay       : yes

    vmListController = new KDListViewController
      view           : new KDListView
        itemClass    : VMListItem
        type         : "vmlist"

    KD.singletons.vmController.fetchVMs (err, vms)->
      return KD.showError err if err
      vmListController.instantiateListItems vms
      modal.addSubView vmListController.getListView()

    vmListController.getListView().on "VmStateChanged", (options)=>
      KD.singletons.vmController.fetchVmInfo options.hostnameAlias, (err, info)=>
        return KD.showError err if err
        if options.state then @controller.mountVm info else \
        @controller.unmountVm info.hostnameAlias


class VMListItem extends KDListItemView

  constructor:(options={}, data)->
    super options, data
    {hostnameAlias} = @getData()
    KD.singletons.vmController.info hostnameAlias, (err, name, info)=>
      return KD.showError err if err
      @addSubView vmLabel  = new KDLabelView title: hostnameAlias
      @addSubView vmSwitch = new KodingSwitch
        cssClass     : 'dark'
        defaultValue : if info.state is "RUNNING" then true else false
        callback     : (state)=>
          @getDelegate().emit "VmStateChanged", {state, hostnameAlias}

  viewAppended:JView::viewAppended
