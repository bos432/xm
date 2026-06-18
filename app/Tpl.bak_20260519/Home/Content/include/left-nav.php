<div class="sidebar-nav" id="sidebar-nav">
    <div id="nav-top"></div>


    <a href="#nav_b" class="nav-header" data-toggle="collapse" id="nav_b_p">
        <i class="icon-briefcase"></i>
        项目申报管理
        <i class="icon-chevron-up"></i>
        <?php if($_COOKIE['pro']>0){ ?>
            <span class="label label-info"><?php echo $_COOKIE['pro'];?></span>
        <?php }?>
    </a>

    <ul id="nav_b" class="nav nav-list collapse">
        <li  <?php if ($action_name=='app_project'){  echo 'class="active"'; }?>>
            <a href="index.php?m=Admin&a=app_project">
                待审核申报
                <?php if($_COOKIE['pro']>0){ ?>
                     <span class="label label-info"><?php echo $_COOKIE['pro'];?></span>
                <?php }?>
            </a>
        </li>

        <li <?php if ($action_name=='app_project_ok'){  echo 'class="active"'; }?>>
            <a href="index.php?m=Admin&a=app_project_ok">
                已审核申报
            </a>
        </li>

        <li <?php if ($action_name=='app_project_recomm'){  echo 'class="active"'; }?>>
            <a href="index.php?m=Admin&a=app_project_recomm">
                已推荐申报
            </a>
        </li>

        <li <?php if ($action_name=='add_useful'){  echo 'class="active"'; }?> >
            <a href="index.php?m=Admin&a=add_useful">项目列表</a>
        </li>

        <li <?php if ($action_name=='project_guess'){  echo 'class="active"'; }?>>
            <a href="index.php?m=Admin&a=project_guess">项目进度查看</a>
        </li>

        <li <?php if ($action_name=='project_search'){  echo 'class="active"'; }?>>
            <a href="index.php?m=Admin&a=project_search">项目查询统计</a>
        </li>
    </ul>
    <a href="#nav_c" class="nav-header" data-toggle="collapse" id="nav_c_p">
        <i class="icon-group"></i>
        用户账号管理
        <i class="icon-chevron-up"></i>
        <?php if($_COOKIE['unit']>0){ ?>
            <span class="label label-info"><?php echo $_COOKIE['unit'];?></span>
        <?php }?>
    </a>

    <ul id="nav_c" class="nav nav-list collapse">
        <li <?php if ($action_name=='check_user'){  echo 'class="active"'; }?> >
            <a href="index.php?m=Admin&a=check_user">审核注册账号
                <?php if($_COOKIE['unit']>0){ ?>
                    <span class="label label-info"><?php echo $_COOKIE['unit'];?></span>
                <?php }?>
            </a>
        </li>

        <li <?php if ($action_name=='user'){  echo 'class="active"'; }?> >
            <a href="index.php?m=Admin&a=user">申报单位账号
            </a>
        </li>

        <li  <?php if ($action_name=='admin_new'){  echo 'class="active"'; }?> >
            <a href="index.php?m=Admin&a=admin_new">新建管理员账号</a>
        </li>

        <li <?php if ($action_name=='admin_list' && $getrole ==1){  echo 'class="active"'; }?> >
            <a href="index.php?m=Admin&a=admin_list&role=1">归口管理账号</a>
        </li>
        <li <?php if ($action_name=='admin_list' && $getrole ==2){  echo 'class="active"'; }?>  >
            <a href="index.php?m=Admin&a=admin_list&role=2">专家账号</a>
        </li>
        <li <?php if ($action_name=='admin_list' && $getrole ==3){  echo 'class="active"'; }?> >
            <a href="index.php?m=Admin&a=admin_list&role=3">盟科技局账号</a>
        </li>

    </ul>

    <a href="#nav_d" class="nav-header" data-toggle="collapse" id="nav_d_p">
        <i class="icon-edit"></i>
        前端管理
        <i class="icon-chevron-up"></i>
    </a>

    <ul id="nav_d" class="nav nav-list collapse">

        <li <?php if ($action_name=='cmslist' && $kind == 1){  echo 'class="active"'; }?>>
            <a href="index.php?m=Admin&a=cmslist&kind=1">公告管理</a>
        </li>
        <li <?php if ($action_name=='cmslist' && $kind == 4){  echo 'class="active"'; }?>>
            <a href="index.php?m=Admin&a=cmslist&kind=4">资讯管理</a>
        </li>
        <li  <?php if ($action_name=='cmslist' && $kind == 5){  echo 'class="active"'; }?>>
            <a href="index.php?m=Admin&a=cmslist&kind=5">科技政策管理</a>
        </li>

        <li  <?php if ($action_name=='cmslist' && $kind == 6){  echo 'class="active"'; }?>>
            <a href="index.php?m=Admin&a=cmslist&kind=6">常见问题管理</a>
        </li>

        <li <?php if ($action_name=='cmslist' && $kind == 3){  echo 'class="active"'; }?>>
            <a href="index.php?m=Admin&a=cmslist&kind=3">文件下载管理</a>
        </li>

        <li <?php if ($action_name=='nav'){  echo 'class="active"'; }?>>
            <a href="index.php?m=Content&a=nav">前端导航栏</a>
        </li>

        <!--
        <li>
            <a href="index.php?m=Admin&a=reply">回复留言</a>
        </li> -->
    </ul>



    <a href="#nav_g" class="nav-header" data-toggle="collapse" id="nav_g_p">
        <i class="icon-list"></i>
        分类管理
        <i class="icon-chevron-up"></i>
    </a>

    <ul id="nav_g" class="nav nav-list collapse">

        <li  <?php if ($action_name=='projecttype'){  echo 'class="active"'; }?>>
            <a href="index.php?m=Admin&a=projecttype">
                归口管理单位
            </a>
        </li>

        <li  <?php if ($action_name=='classfi'){  echo 'class="active"'; }?>>
            <a href="index.php?m=Admin&a=classfi">
                专家领域
            </a>
        </li>

        <li  <?php if ($action_name=='city'){  echo 'class="active"'; }?>>
            <a  href="index.php?m=Admin&a=city">
                旗区
            </a>
        </li>

        <li  <?php if ($action_name=='flow'){  echo 'class="active"'; }?>>
            <a  href="index.php?m=Content&a=flow">
                评审标题
            </a>
        </li>
    </ul>

    <a href="#nav_h" class="nav-header" data-toggle="collapse" id="nav_h_p">
        <i class="icon-list"></i>
        站点配置
        <i class="icon-chevron-up"></i>
    </a>

    <ul id="nav_h" class="nav nav-list collapse">
        <li <?php if ($action_name=='config'){  echo 'class="active"'; }?>>
            <a href="index.php?m=Admin&a=config">站点配置</a>
        </li>
        <li  <?php if ($action_name=='smsconfig'){  echo 'class="active"'; }?>>
            <a href="index.php?m=Content&a=smsconfig">
                短信配置
            </a>
        </li>
    </ul>

    <!--
    <a href="#nav_e" class="nav-header" data-toggle="collapse" id="nav_e_p">
        <i class="icon-thumbs-up"></i>
        示范企业管理
        <i class="icon-chevron-up"></i>
        <?php if($_COOKIE['model']>0){ ?>
            <span class="label label-info"><?php echo $_COOKIE['model'];?></span>
        <?php }?>
    </a>

    <ul id="nav_e" class="nav nav-list collapse">

        <li  <?php if ($action_name=='app_company'){  echo 'class="active"'; }?>>
            <a href="index.php?m=Admin&a=app_company">
                示范企业审核
                <?php if($_COOKIE['model']>0){ ?>
                    <span class="label label-info"><?php echo $_COOKIE['model'];?></span>
                <?php }?>
            </a>
        </li>

        <li  <?php if ($action_name=='company_search'){  echo 'class="active"'; }?>>
            <a  href="index.php?m=Admin&a=company_search">
                示范企业查询
            </a>
        </li>
    </ul>-->


    <!--
    <a  class="nav-header"   href="index.php?m=Admin&a=change_password">
        <i class="icon-key"></i>
        修改密码
    </a> -->


    <a href="index.php?m=Admin&a=message" class="nav-header" >
        <i class="icon-comment"></i>
        消息
        <?php if($_COOKIE['message']>0){ ?>
            <span class="label label-info"><?php echo $_COOKIE['message'];?></span>
        <?php }?>
    </a>

    <a href="index.php?m=Admin&a=help" class="nav-header" >
        <i class="icon-question-sign"></i>
        帮助文档
    </a>

	<a style="display: none" href="index.php?m=Admin&a=set_mail" class="nav-header" >
        <i class="icon-question-sign"></i>
        设置密码找回邮箱
    </a>

    <a href="#nav_f" class="nav-header" data-toggle="collapse" id="nav_f_p">
        <i class="icon-lock"></i>
        数据库日志
        <i class="icon-chevron-up"></i>
    </a>

    <ul id="nav_f" class="nav nav-list collapse">

        <li <?php if ($action_name=='control'){  echo 'class="active"'; }?>>
            <a href="index.php?m=Admin&a=control" >
                权限控制
            </a>
        </li >

        <li <?php if ($action_name=='smsloglist'){  echo 'class="active"'; }?>>
            <a href="index.php?m=Admin&a=smsloglist">短信日志</a>
        </li>

        <li <?php if ($action_name=='loglist'){  echo 'class="active"'; }?>>
            <a href="index.php?m=Admin&a=loglist">操作日志</a>
        </li>

        <li style="display:none;">
            <a href="index.php?m=Admin&a=log_export">日志查看导出</a>
        </li>
        <li <?php if ($action_name=='copy_sql'){  echo 'class="active"'; }?>>
            <a href="index.php?m=Admin&a=copy_sql">备份数据库</a>
        </li>
    </ul>
</div>