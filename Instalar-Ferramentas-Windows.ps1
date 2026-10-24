$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms

$dialog = New-Object System.Windows.Forms.FolderBrowserDialog
$dialog.Description = "Selecione a pasta da Central de Investimentos da sua irmã"
$dialog.ShowNewFolderButton = $false

if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "Instalação cancelada."
    exit 0
}

$destino = $dialog.SelectedPath
$html = Join-Path $destino "central-investimentos.html"
$servidor = Join-Path $destino "servidor.py"
$ferramentas = Join-Path $PSScriptRoot "ferramentas-financeiras.html"

if (!(Test-Path $html) -or !(Test-Path $servidor)) {
    throw "A pasta selecionada não contém central-investimentos.html e servidor.py. Nada foi instalado."
}

if (!(Test-Path $ferramentas)) {
    throw "Não encontrei ferramentas-financeiras.html junto do instalador."
}

$codigo = [IO.File]::ReadAllText($servidor)
if ($codigo -notmatch '(?m)^\s*app\s*=\s*Flask\(') {
    throw "Não identifiquei com segurança a aplicação Flask. Nenhum arquivo foi alterado."
}

$backup = Join-Path $destino ("backup-ferramentas-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
New-Item -ItemType Directory -Path $backup | Out-Null

Copy-Item $html (Join-Path $backup "central-investimentos.html")
Copy-Item $servidor (Join-Path $backup "servidor.py")

try {
    Copy-Item $ferramentas (Join-Path $destino "ferramentas-financeiras.html") -Force

    if ($codigo -notmatch 'def pagina_ferramentas_financeiras') {
        $rota = @'
@app.route("/ferramentas-financeiras")
def pagina_ferramentas_financeiras():
    arquivo = __import__("pathlib").Path(__file__).resolve().parent / "ferramentas-financeiras.html"
    return arquivo.read_text(encoding="utf-8")

'@

        $pos = $codigo.IndexOf('if __name__ == "__main__":')
        if ($pos -lt 0) {
            $pos = $codigo.IndexOf("if __name__ == '__main__':")
        }

        if ($pos -ge 0) {
            $codigo = $codigo.Insert($pos, $rota)
        } else {
            $codigo += "`r`n" + $rota
        }

        [IO.File]::WriteAllText($servidor, $codigo, (New-Object System.Text.UTF8Encoding($false)))
    }

    $pagina = [IO.File]::ReadAllText($html)

    if ($pagina -notmatch 'id="abrirFerramentasFinanceirasPresente"') {
        $atalho = @'
<!-- Atalho independente para as ferramentas financeiras -->
<button id="abrirFerramentasFinanceirasPresente" type="button"
style="position:fixed;left:16px;bottom:16px;z-index:9998;background:#153426;color:#fff;border:2px solid #00dc46;border-radius:10px;padding:12px 15px;font-weight:800;cursor:pointer;box-shadow:0 4px 18px #0008">
🧮 Ferramentas de Investimento
</button>
<script>
(function(){
  var b=document.getElementById("abrirFerramentasFinanceirasPresente");
  if(b)b.addEventListener("click",function(){
    window.open("/ferramentas-financeiras","_blank","noopener");
  });
})();
</script>
'@

        if ($pagina -match '(?i)</body>') {
            $pagina = [regex]::Replace($pagina, '(?i)</body>', ($atalho + "`r`n</body>"), 1)
        } else {
            $pagina += "`r`n" + $atalho
        }

        [IO.File]::WriteAllText($html, $pagina, (New-Object System.Text.UTF8Encoding($false)))
    }

    Write-Host ""
    Write-Host "Instalação preparada."
    Write-Host "Backup original: $backup"
    Write-Host "Reinicie a Central e teste o botão Ferramentas de Investimento."
} catch {
    Copy-Item (Join-Path $backup "central-investimentos.html") $html -Force
    Copy-Item (Join-Path $backup "servidor.py") $servidor -Force
    throw "Falha na instalação. Os dois arquivos originais foram restaurados do backup: $($_.Exception.Message)"
}
