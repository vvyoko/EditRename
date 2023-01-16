### EditRename
-  用熟悉的文本编辑器,所见即所得的重命名


### 使用
- 运行`EditRename.exe`, 选择编辑器
    - 编辑器需能在标题显示文件名
- 不要调整行顺序,不要删除行
- 点击`更多设置`查看使用方法及其他设置
- 传入参数
    - 拖拽文件至界面上
    - 将路径复制到剪贴板,然后将 `clip` 作为唯一参数传入
    - 将所有文件路径保存至 `%temp%` 目录下的指定文件,然后将此文件作为唯一参数传入
    - 拖拽文件到程序图标 `有文件数量限制`
- 关闭编辑器时会自动重命名
    - 多标签编辑器并设置`muiltTab`为`1`时切换标签立即进行重命名
- 修改错误时右键托盘图标退出或直接关闭界面
- `路径` 需编辑器支持重新加载外部修改
    - `不带扩展名` 指不带扩展名的文件名
    - 大部分编辑器支持重载(`notepad2`,`notepad3`,`notepad++`,`vscode`...)
    - 如不支持则需关闭并重新传入参数
- `恢复`
    - 通过界面点击恢复
        - 部分会显示所有可恢复文件,删除不必要的保存并退出进行恢复
    - 通过托盘恢复上次
    - 如`log.txt`变大 全部及部分恢复可能变慢,可删除此文件

### ini设置
- 点击`更多设置`查看说明
- ini编辑完设置会在下一次运行时生效
- `secondEditor` 备用编辑器
    - 一些类似IDE的编辑器启动较慢,如已经运行则使用此编辑器,否则使用默认编辑器
    - 参考`editor`手动设置路径
- `gui` 设为0不显示界面,除非直接运行
- `muiltTab` 多标签编辑器切换标签时立即重命名
- `formatName` 对文件名 移除首尾空格,替换非法字符为空
- `reArr` 自定义替换
    - 格式为 `;搜索项;替换项;是否正则(0或1)`
    - 增加需要递增序号 如 `2=;@{2,};@;1` 替换多个`@`为单个
    - 自带示例为正则替换多个空白为单个空白
- 不在界面上显示所有设置的原因是界面是置顶的,需尽量小避免干扰

### 截图
![gif](gif.gif)

### 下载链接 :
[百度云](https://pan.baidu.com/s/1NY4ov9B7eLPH1ogTn7OoVg?pwd=su4z)

[Github]( https://github.com/vvyoko/EditRename/releases/latest)
